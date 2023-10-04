#!/bin/bash

set -euo pipefail

# Don't error when no files are found
shopt -s nullglob

FILES="${HOME}/Downloads/Printers/*.dmg"

for FILE in ${FILES}; do
    # Mount the file as a volume. Note that the printer drivers are nested underneath a folder structure starting from Root.
    PRINTER_FOLDER='/';
    echo "Mounting ${FILE} image";
    VOLUME=$(hdiutil mount "${FILE}" | tail -n1 | perl -nle '/(\/Volumes\/[^\b]+)/; print $1');

    # Locate .app folder and move to /Applications
    echo "Attempting to locate ${VOLUME}";
    APP=$(find "${VOLUME}"/ -name '*.app' -maxdepth 1 -type d -print0);
    echo "Copying $(echo "${APP}" | awk -F/ '{print $NF}') into ${PRINTER_FOLDER}...";
    \cp -iR "${APP}" "${PRINTER_FOLDER}";

    # Unmount volume, delete temporary file
    echo "Cleaning up...";
    hdiutil unmount "${VOLUME}" -quiet;
    \rm "${FILE}";
    echo "Done!";
done

# unset it now
shopt -u nullglob