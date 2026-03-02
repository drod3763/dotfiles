import { existsSync, readdirSync, statSync } from "node:fs"
import { homedir, platform } from "node:os"
import { join } from "node:path"

export const SyncOpencodeSessionsPlugin = async ({ $, client }) => {
  let pushInProgress = false
  let pullInProgress = false

  const retentionDays = Number.parseInt(process.env.OPENCODE_SYNC_RETENTION_DAYS ?? "14", 10)
  const pullOnStart = process.env.OPENCODE_SYNC_PULL_ON_START !== "0"
  const keepDays = Number.isNaN(retentionDays) ? 14 : Math.max(1, retentionDays)

  const cutoffMs = () => Date.now() - keepDays * 24 * 60 * 60 * 1000

  const walkFiles = (root) => {
    const files = []
    if (!existsSync(root)) return files

    for (const entry of readdirSync(root, { withFileTypes: true })) {
      const fullPath = join(root, entry.name)
      if (entry.isDirectory()) files.push(...walkFiles(fullPath))
      else files.push(fullPath)
    }

    return files
  }

  const runtimeSyncPaths = () => {
    const home = homedir()
    const paths = {
      filteredDirs: [
        join(home, ".local", "share", "opencode", "storage", "session"),
        join(home, ".local", "share", "opencode", "storage", "message"),
        join(home, ".local", "share", "opencode", "storage", "part"),
        join(home, ".local", "share", "opencode", "storage", "session_diff"),
      ],
      alwaysDirs: [join(home, ".local", "share", "opencode", "storage", "project")],
      alwaysFiles: [join(home, ".local", "state", "opencode", "prompt-history.jsonl")],
    }

    if (platform() === "darwin") {
      paths.filteredDirs.push(
        join(home, "Library", "Application Support", "opencode", "storage", "session"),
        join(home, "Library", "Application Support", "opencode", "storage", "message"),
        join(home, "Library", "Application Support", "opencode", "storage", "part"),
        join(home, "Library", "Application Support", "opencode", "storage", "session_diff"),
      )
      paths.alwaysDirs.push(join(home, "Library", "Application Support", "opencode", "storage", "project"))
      paths.alwaysFiles.push(join(home, "Library", "Application Support", "opencode", "state", "prompt-history.jsonl"))
    }

    return paths
  }

  const syncRecentRuntimeData = async () => {
    const paths = runtimeSyncPaths()
    const cutoff = cutoffMs()

    for (const dir of paths.alwaysDirs) {
      if (!existsSync(dir)) continue
      await $`chezmoi add --encrypt --recursive ${dir}`.quiet()
    }

    for (const file of paths.alwaysFiles) {
      if (!existsSync(file)) continue
      await $`chezmoi add --encrypt ${file}`.quiet()
    }

    for (const dir of paths.filteredDirs) {
      if (!existsSync(dir)) continue

      for (const file of walkFiles(dir)) {
        // Keep global session metadata regardless of age.
        if (file.includes("/storage/session/global/")) {
          await $`chezmoi add --encrypt ${file}`.quiet()
          continue
        }

        if (statSync(file).mtimeMs < cutoff) continue
        await $`chezmoi add --encrypt ${file}`.quiet()
      }
    }
  }

  const pruneOldRepoFiles = async () => {
    const home = homedir()
    const repo = join(home, ".local", "share", "chezmoi")
    if (!existsSync(repo)) return

    const pruneTargets = [
      "home/dot_local/share/opencode/storage/message -type f -name 'encrypted_*.age' -mtime +${KEEP_DAYS}",
      "home/dot_local/share/opencode/storage/part -type f -name 'encrypted_*.age' -mtime +${KEEP_DAYS}",
      "home/dot_local/share/opencode/storage/session_diff -type f -name 'encrypted_*.age' -mtime +${KEEP_DAYS}",
      "home/dot_local/share/opencode/storage/session -type f -name 'encrypted_*.age' -mtime +${KEEP_DAYS} ! -path '*/session/global/*'",
      "home/Library/Application Support/opencode/storage/message -type f -name 'encrypted_*.age' -mtime +${KEEP_DAYS}",
      "home/Library/Application Support/opencode/storage/part -type f -name 'encrypted_*.age' -mtime +${KEEP_DAYS}",
      "home/Library/Application Support/opencode/storage/session_diff -type f -name 'encrypted_*.age' -mtime +${KEEP_DAYS}",
      "home/Library/Application Support/opencode/storage/session -type f -name 'encrypted_*.age' -mtime +${KEEP_DAYS} ! -path '*/session/global/*'",
    ]

    for (const target of pruneTargets) {
      const rendered = target.replaceAll("${KEEP_DAYS}", String(keepDays))
      await $`bash -lc ${`find ${rendered} -print0 2>/dev/null | xargs -0r git rm -f --`}`
        .cwd(repo)
        .quiet()
    }

    await $`bash -lc ${
      "find home/dot_local/share/opencode/storage -type d -empty -not -path '*/project*' -delete 2>/dev/null || true"
    }`
      .cwd(repo)
      .quiet()
  }

  const pushEncryptedOpencodeData = async () => {
    if (pushInProgress) return
    pushInProgress = true

    try {
      await $`command -v chezmoi`.quiet()

      await syncRecentRuntimeData()

      await pruneOldRepoFiles()
    } catch (error) {
      await client.app.log({
        body: {
          service: "sync-opencode-sessions",
          level: "warn",
          message: "Failed to sync encrypted opencode sessions",
          extra: { error: String(error) },
        },
      })
    } finally {
      pushInProgress = false
    }
  }

  const pullLatestOpencodeData = async () => {
    if (pullInProgress) return
    pullInProgress = true

    try {
      await $`command -v chezmoi`.quiet()
      const statusOutput = await $`chezmoi status`.text()
      if (!statusOutput.includes("opencode")) return

      const home = homedir()
      const targets = [
        join(home, ".local", "share", "opencode", "storage"),
        join(home, ".local", "state", "opencode"),
      ]

      if (platform() === "darwin") {
        targets.push(join(home, "Library", "Application Support", "opencode", "storage"))
      }

      for (const target of targets) {
        if (!existsSync(target)) continue
        await $`chezmoi apply --exclude=scripts ${target}`.quiet()
      }
    } catch (error) {
      await client.app.log({
        body: {
          service: "sync-opencode-sessions",
          level: "warn",
          message: "Failed to pull opencode session data",
          extra: { error: String(error) },
        },
      })
    } finally {
      pullInProgress = false
    }
  }

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle" || event.type === "session.deleted") {
        void pushEncryptedOpencodeData()
      }

      if (pullOnStart && event.type === "server.connected") {
        void pullLatestOpencodeData()
      }
    },
  }
}
