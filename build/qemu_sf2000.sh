#!/bin/sh
# S0.6: the SF2000 core as MIPS32 soft-float (zig mipsel-linux-musleabi) inside the host, under qemu-user in WSL.
# Run through PowerShell (Git Bash rewrites /mnt paths):
#   wsl.exe -d Ubuntu-22.04 -e sh $REPO_WSL/build/qemu_sf2000.sh [host options...]
# qemu needs -B 0x10000000 under WSL1: without it the guest address space reservation fails (-R does not help).

# the repository as WSL sees it (C:\dir -> /mnt/c/dir), so this works wherever the repository was cloned.
# Two steps on purpose: `A 2>/dev/null || B && C` runs C after a SUCCESSFUL A too, and the variable then holds
# two lines - which reaches `sh -c` as a broken multi-line script.
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
REPO_WIN=$(cd "$REPO_DIR" && pwd -W 2>/dev/null) || REPO_WIN=$REPO_DIR
REPO_DRIVE_UPPER=$(printf '%s' "$REPO_WIN" | cut -c1)
REPO_DRIVE=$(printf '%s' "$REPO_DRIVE_UPPER" | tr 'A-Z' 'a-z')
REPO_WSL="/mnt/$REPO_DRIVE$(printf '%s' "$REPO_WIN" | cut -c3- | tr '\\' '/')"

ls '$REPO_WSL' >/dev/null 2>&1 || sudo -n mount -t drvfs ${REPO_DRIVE_UPPER}: /mnt/${REPO_DRIVE}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
mkdir -p out/sf2000/hostcard/ROMS/bobrhopper
[ -f out/sf2000/hostcard/ROMS/bobrhopper/start ] || : > out/sf2000/hostcard/ROMS/bobrhopper/start
qemu-mipsel-static -B 0x10000000 out/sf2000/host/sf2000_host.mipsel "$@"
rc=$?
echo "qemu_sf2000: rc=$rc"
exit $rc
