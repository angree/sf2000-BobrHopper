#!/bin/sh
# S0.6: the game logic as MIPS32 soft-float (out/sf2000/host/trace.mipsel, build/build_host.sh mipsel-trace) runs every
# scenario of build/trace_scenarios.txt under qemu-user in WSL, writing out/trace_mips/<name>.txt for comparison with the
# PC port's out/trace_port/. Run through PowerShell or build/sf2000_mips_test.sh.

# the repository as WSL sees it (C:\dir -> /mnt/c/dir), so this works wherever the repository was cloned.
# Two steps on purpose: `A 2>/dev/null || B && C` runs C after a SUCCESSFUL A too, and the variable then holds
# two lines - which reaches `sh -c` as a broken multi-line script.
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
REPO_WIN=$(cd "$REPO_DIR" && pwd -W 2>/dev/null) || REPO_WIN=$REPO_DIR
REPO_DRIVE_UPPER=$(printf '%s' "$REPO_WIN" | cut -c1)
REPO_DRIVE=$(printf '%s' "$REPO_DRIVE_UPPER" | tr 'A-Z' 'a-z')
REPO_WSL="/mnt/$REPO_DRIVE$(printf '%s' "$REPO_WIN" | cut -c3- | tr '\\' '/')"

ls '$REPO_WSL' >/dev/null 2>&1 || sudo -n mount -t drvfs ${REPO_DRIVE_UPPER}: /mnt/${REPO_DRIVE}
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 1
mkdir -p out/trace_mips
fail=0
grep -v '^#' build/trace_scenarios.txt | while IFS='|' read -r name seed steps script; do
  [ -z "$name" ] && continue
  pre=$(sed -n 's/^pre_ticks //p' "out/trace_ref/$name.txt" 2>/dev/null)
  qemu-mipsel-static -B 0x10000000 out/sf2000/host/trace.mipsel --seed "$seed" --steps "$steps" --pre "${pre:-0}" \
    --script "$script" --out "out/trace_mips/$name.txt" > /dev/null 2>&1 || { echo "qemu_traces: $name rc=$?"; }
done
echo "qemu_traces: done"
