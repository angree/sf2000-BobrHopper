#!/bin/sh
# Runs an aarch64 build under qemu-user inside WSL against the buster sysroot (no GPU: headless).
#   wsl.exe -d Ubuntu-22.04 -e sh $REPO_WSL/build/qemu_smoke.sh probe --headless --frames 120

# the repository as WSL sees it (C:\dir -> /mnt/c/dir), so this works wherever the repository was cloned.
# Two steps on purpose: `A 2>/dev/null || B && C` runs C after a SUCCESSFUL A too, and the variable then holds
# two lines - which reaches `sh -c` as a broken multi-line script.
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
REPO_WIN=$(cd "$REPO_DIR" && pwd -W 2>/dev/null) || REPO_WIN=$REPO_DIR
REPO_DRIVE_UPPER=$(printf '%s' "$REPO_WIN" | cut -c1)
REPO_DRIVE=$(printf '%s' "$REPO_DRIVE_UPPER" | tr 'A-Z' 'a-z')
REPO_WSL="/mnt/$REPO_DRIVE$(printf '%s' "$REPO_WIN" | cut -c3- | tr '\\' '/')"

set -e
ls '$REPO_WSL' >/dev/null 2>&1 || sudo -n mount -t drvfs ${REPO_DRIVE_UPPER}: /mnt/${REPO_DRIVE}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SYSROOT=/opt/crossy-sysroot
TARGET=$1
shift
WORK=/tmp/crossy-qemu
mkdir -p "$WORK"
cd "$WORK"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  qemu-aarch64-static -L "$SYSROOT" "$ROOT/out/r36s/$TARGET.aarch64" "$@"
rc=$?
echo "qemu_smoke: $TARGET rc=$rc"
exit $rc
