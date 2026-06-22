#!/usr/bin/env bun
// Two-step formatter for TOML-producing chezmoi templates (*.toml.tmpl).
//
// prettier (the go-template formatter) has no TOML parser and reflows the TOML
// body into invalid output, so these files are handled here instead.
//
//   Step 1  Normalize Go `{{ ... }}` expressions (delimiter padding, inner
//           spacing) without touching the surrounding TOML. Hermetic.
//   Step 2  Render the template, run `taplo format` on the rendered TOML, then
//           map taplo's whitespace changes back onto the static (non-template)
//           source lines. Skipped gracefully when the template cannot render.
//
// Safety: after editing, the rendered output must be semantically identical to
// the original (taplo(render_before) == taplo(render_after)); otherwise the
// file is restored and the run fails.
//
// Usage: bun format_toml_template.js <file.toml.tmpl> [more...]

import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

// --- shell helpers ----------------------------------------------------------

function run(cmd, args, input) {
  const res = spawnSync(cmd, args, {
    input: input ?? undefined,
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
  });
  return { ok: res.status === 0, stdout: res.stdout ?? "", stderr: res.stderr ?? "" };
}

function renderTemplate(text) {
  // chezmoi execute-template reads the template from stdin and uses the current
  // machine's data. Failure (e.g. promptBool) means "not renderable here".
  // Retry once to absorb transient backends (e.g. 1Password throttling when
  // several templates render back-to-back).
  let res = run("chezmoi", ["execute-template"], text);
  if (!res.ok) res = run("chezmoi", ["execute-template"], text);
  return res;
}

function taploFormat(text) {
  const res = run("taplo", ["format", "--no-auto-config", "-o", "reorder_keys=false", "-"], text);
  if (!res.ok) throw new Error(`taplo format failed: ${res.stderr.trim()}`);
  return res.stdout;
}

// --- step 1: Go-expression normalization ------------------------------------

// Normalize the inside of a single `{{ ... }}` action while preserving quoted
// strings. Leaves `{{/* ... */}}` comments untouched.
function normalizeAction(open, body, close) {
  if (body.trimStart().startsWith("/*")) return open + body + close; // comment

  // Collapse whitespace runs that sit outside quoted strings.
  let out = "";
  let quote = null; // active quote char or null
  for (let i = 0; i < body.length; i++) {
    const ch = body[i];
    if (quote) {
      out += ch;
      if (ch === quote && body[i - 1] !== "\\") quote = null;
      continue;
    }
    if (ch === '"' || ch === "'" || ch === "`") {
      quote = ch;
      out += ch;
      continue;
    }
    if (/\s/.test(ch)) {
      if (out.length && !/\s$/.test(out)) out += " ";
      continue;
    }
    out += ch;
  }
  out = out.trim();
  // Conservative operator spacing (outside strings already collapsed above).
  out = out.replace(/\s*:=\s*/g, " := ");
  return `${open} ${out} ${close}`;
}

function normalizeGoExpressions(src) {
  // Match `{{`/`{{-` ... `}}`/`-}}`, non-greedy. Template actions do not nest.
  return src.replace(/(\{\{-?)([\s\S]*?)(-?\}\})/g, (_m, open, body, close) =>
    normalizeAction(open, body, close),
  );
}

// --- step 2: map taplo whitespace back onto static source lines -------------

// Alignment key: ignores the exact whitespace taplo normalizes (leading indent,
// spacing around `=`) so a line and its reformatted form compare equal.
const key = (line) =>
  line
    .replace(/\s*=\s*/g, "=")
    .replace(/\s+/g, " ")
    .trim();

// Longest-common-subsequence pairing of two arrays by `key`. Returns pairs of
// matched indices [i, j] in increasing order.
function lcsPairs(a, b) {
  const n = a.length;
  const m = b.length;
  const dp = Array.from({ length: n + 1 }, () => new Int32Array(m + 1));
  for (let i = n - 1; i >= 0; i--) {
    for (let j = m - 1; j >= 0; j--) {
      dp[i][j] = a[i] === b[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  const pairs = [];
  let i = 0;
  let j = 0;
  while (i < n && j < m) {
    if (a[i] === b[j]) {
      pairs.push([i, j]);
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return pairs;
}

function mapBackToml(srcLines, rOrig, rFmt) {
  const roKeys = rOrig.map(key);
  const rfKeys = rFmt.map(key);

  // Learn taplo's canonical form per line-key. Static source lines render
  // verbatim, so a rendered line and its source line share a key; taplo is
  // deterministic, so every line with a given key gets the same formatted form
  // regardless of position. Positionally align rendered-original -> formatted,
  // then index the result by key. A key that resolves to conflicting forms is
  // dropped (left untouched) to stay safe.
  const transform = new Map();
  const conflict = new Set();
  for (const [i, j] of lcsPairs(roKeys, rfKeys)) {
    const k = roKeys[i];
    const form = rFmt[j];
    if (transform.has(k) && transform.get(k) !== form) conflict.add(k);
    else transform.set(k, form);
  }

  return srcLines.map((line) => {
    if (line.includes("{{")) {
      // Template line: taplo never sees it, but TOML ignores leading indent,
      // so strip it to match the dedented body. The render guardrail verifies
      // this stays semantically identical.
      return line.replace(/^[ \t]+/, "");
    }
    const k = key(line);
    if (conflict.has(k) || !transform.has(k)) return line; // unmatched: keep
    return transform.get(k);
  });
}

// --- per-file driver --------------------------------------------------------

function formatFile(path) {
  const original = readFileSync(path, "utf8");

  // Step 1 — always safe, no render required.
  let result = normalizeGoExpressions(original);

  // Step 2 — needs a successful render; skip cleanly otherwise.
  const renderBefore = renderTemplate(original);
  if (renderBefore.ok) {
    const rOrig = renderBefore.stdout;
    const rFmt = taploFormat(rOrig);
    if (rFmt !== rOrig) {
      const mapped = mapBackToml(result.split("\n"), rOrig.split("\n"), rFmt.split("\n"));
      result = mapped.join("\n");
    }
  } else {
    process.stderr.write(`format_toml_template: skip step 2 (template not renderable here): ${path}\n`);
  }

  if (result === original) return false; // nothing to do

  // Safety guardrail: edits must not change the semantic TOML output.
  if (renderBefore.ok) {
    const after = renderTemplate(result);
    if (!after.ok) {
      throw new Error(`${path}: edited template no longer renders: ${after.stderr.trim()}`);
    }
    if (taploFormat(after.stdout) !== taploFormat(renderBefore.stdout)) {
      throw new Error(`${path}: refusing to write — rendered output would change`);
    }
  }

  writeFileSync(path, result);
  return true;
}

// --- entry ------------------------------------------------------------------

const files = process.argv.slice(2);
if (files.length === 0) {
  process.stderr.write("usage: format_toml_template.js <file.toml.tmpl> [...]\n");
  process.exit(2);
}

let failed = false;
for (const f of files) {
  try {
    formatFile(resolve(f));
  } catch (err) {
    failed = true;
    process.stderr.write(`${err.message}\n`);
  }
}
process.exit(failed ? 1 : 0);
