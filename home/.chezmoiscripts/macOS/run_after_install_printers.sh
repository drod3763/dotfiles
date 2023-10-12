#!/bin/bash

set -euo pipefail

# Don't error when no files are found
shopt -s nullglob

FILES="${HOME}/Downloads/Printers/*.dmg"

for FILE in ${FILES}; do
    # Mount the file as a volume. Note that the printer drivers are nested underneath a folder structure starting from Root.
    ROOT="/";
    echo "Mounting ${FILE} image";
    VOLUME=$(hdiutil mount "${FILE}" | tail -n1 | perl -nle '/(\/Volumes\/[^\b]+)/; print $1');

    # Locate .app folder and move to /Applications
    echo "Attempting to locate the volume ${VOLUME}...";
    PKG=$(find "${VOLUME}" -name '*.pkg' -maxdepth 1 -type f -print0);
    echo "Installing $(echo "${PKG}" | awk -F/ '{print $NF}') into ${ROOT}...";
    sudo installer -pkg "${PKG}" -target "${ROOT}"
    # Unmount volume, delete temporary file
    echo "Cleaning up...";
    hdiutil unmount "${VOLUME}" -quiet;
    \rm "${FILE}";
    echo "Done!";
done

# unset it now
shopt -u nullglob