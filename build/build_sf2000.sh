#!/bin/sh
# SF2000 build (Git Bash on Windows): the MIPS toolchain (Codescape mips-mti-elf GCC 7.4.0) lives in WSL, so this
# generates the headers that need Windows Python and hands over to build/sf2000_wsl.sh inside Ubuntu-22.04.
# Usage: sh build/build_sf2000.sh <target>   targets: sf2000_logic, sf2000_core (see build/sources.sh)

# the repository as WSL sees it (C:\dir -> /mnt/c/dir), so this works wherever the repository was cloned.
# Two steps on purpose: `A 2>/dev/null || B && C` runs C after a SUCCESSFUL A too, and the variable then holds
# two lines - which reaches `sh -c` as a broken multi-line script.
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
REPO_WIN=$(cd "$REPO_DIR" && pwd -W 2>/dev/null) || REPO_WIN=$REPO_DIR
REPO_DRIVE_UPPER=$(printf '%s' "$REPO_WIN" | cut -c1)
REPO_DRIVE=$(printf '%s' "$REPO_DRIVE_UPPER" | tr 'A-Z' 'a-z')
REPO_WSL="/mnt/$REPO_DRIVE$(printf '%s' "$REPO_WIN" | cut -c3- | tr '\\' '/')"

TARGET=${1:-sf2000_core}
cd "$(dirname "$0")/.." || exit 1
python tools/font_to_header.py data/fonts/retro_12.fnt out/sf2000/gen/boot_font.h || exit 1
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-22.04 -e sh -c \
  "ls '$REPO_WSL' >/dev/null 2>&1 || sudo -n mount -t drvfs ${REPO_DRIVE_UPPER}: /mnt/${REPO_DRIVE}; SF2000_BASE_ROOT='$SF2000_BASE_ROOT' sh $REPO_WSL/build/sf2000_wsl.sh $TARGET"
