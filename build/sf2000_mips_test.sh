#!/bin/sh
# S0.6/F6: the SF2000 code (16.16, CR_FIXED) built as MIPS32 soft-float gives bit-identical results to the same code
# built for the PC:
#   1. the core in the host, bench mode: PC exe and mipsel under qemu -> same frame hash, same bench digest
#   2. the game logic: every trace scenario with the 16.16 trace tool on the PC (out/trace_fixed) and as mipsel under
#      qemu (out/trace_mips) -> identical traces
# Needs: sh build/build_host.sh pc; mipsel; pc-trace; mipsel-trace
#   sh build/sf2000_mips_test.sh

# the repository as WSL sees it (C:\dir -> /mnt/c/dir), so this works wherever the repository was cloned.
# Two steps on purpose: `A 2>/dev/null || B && C` runs C after a SUCCESSFUL A too, and the variable then holds
# two lines - which reaches `sh -c` as a broken multi-line script.
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
REPO_WIN=$(cd "$REPO_DIR" && pwd -W 2>/dev/null) || REPO_WIN=$REPO_DIR
REPO_DRIVE_UPPER=$(printf '%s' "$REPO_WIN" | cut -c1)
REPO_DRIVE=$(printf '%s' "$REPO_DRIVE_UPPER" | tr 'A-Z' 'a-z')
REPO_WSL="/mnt/$REPO_DRIVE$(printf '%s' "$REPO_WIN" | cut -c3- | tr '\\' '/')"

cd "$(dirname "$0")/.." || exit 1
D=out/check/mips_test
CARD=out/sf2000/hostcard/ROMS/bobrhopper
mkdir -p "$D" "$CARD" out/trace_fixed
: > "$CARD/bench"
fail=0
SCRIPT="w40 hold:a:10 hold:up:5 w20 btn:start shot:end"

# /mnt/i drops out of WSL: mount it first, because wsl.exe cannot even open a script there otherwise
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-22.04 -e sh -c "ls '$REPO_WSL' >/dev/null 2>&1 || sudo -n mount -t drvfs ${REPO_DRIVE_UPPER}: /mnt/${REPO_DRIVE}"

./out/sf2000/host/sf2000_host.exe --frames 120 --rom "$CARD/bench" --shot-dir "$D" --shot-prefix pc --script "$SCRIPT" > "$D/pc.txt" 2>&1
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-22.04 -e sh $REPO_WSL/build/qemu_sf2000.sh --frames 120 \
  --rom "$CARD/bench" --shot-dir "$D" --shot-prefix mips --script "$SCRIPT" > "$D/mips.txt" 2>&1
hp=$(grep -o 'hash=[0-9a-f]*' "$D/pc.txt")
hm=$(grep -o 'hash=[0-9a-f]*' "$D/mips.txt")
if [ -n "$hp" ] && [ "$hp" = "$hm" ]; then echo "  ok   core frame hash PC = MIPS ($hp)"; else echo "  FAIL core frame hash PC '$hp' / MIPS '$hm'"; fail=1; fi
# the bench inside the core finishes its 20000 logic steps after 100 frames
if grep -q "bench digest 8eefa860b4ab642d ok" "$D/mips.txt"; then echo "  ok   MIPS core bench digest = 16.16 reference"; else echo "  FAIL MIPS bench digest: $(grep 'bench digest' "$D/mips.txt")"; fail=1; fi

# C2.1: the game itself - logic, software renderer and UI - draws the same pixels on MIPS as on the PC
: > "$CARD/start"
# without saved settings or best score (a best score is on the HUD, so it changes the frame hash)
rm -f out/sf2000/hostcard/ROMS/bobrhopper/conf/crossy.cfg out/sf2000/hostcard/ROMS/bobrhopper/conf/crossy.cfg.tmp \
  out/sf2000/hostcard/ROMS/bobrhopper/crossy.cfg out/sf2000/hostcard/ROMS/bobrhopper/crossy.cfg.tmp
GAME_SCRIPT="w40 hold:a:4 w30 hold:up:2 w20 hold:left:2 w20 shot:game"
./out/sf2000/host/sf2000_host.exe --frames 130 --rom "$CARD/start" --shot-dir "$D" --shot-prefix pcgame --script "$GAME_SCRIPT" > "$D/pcgame.txt" 2>&1
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-22.04 -e sh $REPO_WSL/build/qemu_sf2000.sh --frames 130 \
  --rom "$CARD/start" --shot-dir "$D" --shot-prefix mipsgame --script "$GAME_SCRIPT" > "$D/mipsgame.txt" 2>&1
hp=$(grep -o 'hash=[0-9a-f]*' "$D/pcgame.txt")
hm=$(grep -o 'hash=[0-9a-f]*' "$D/mipsgame.txt")
if [ -n "$hp" ] && [ "$hp" = "$hm" ]; then echo "  ok   game frame hash PC = MIPS over 130 frames ($hp)"; else echo "  FAIL game frame hash PC '$hp' / MIPS '$hm'"; fail=1; fi
ap=$(grep -o 'audio_fnv=[0-9a-f]*' "$D/pcgame.txt")
am=$(grep -o 'audio_fnv=[0-9a-f]*' "$D/mipsgame.txt")
if [ -n "$ap" ] && [ "$ap" = "$am" ]; then echo "  ok   game audio PC = MIPS ($ap)"; else echo "  FAIL game audio PC '$ap' / MIPS '$am'"; fail=1; fi

total=0
grep -v '^#' build/trace_scenarios.txt | while IFS='|' read -r name seed steps script; do
  [ -z "$name" ] && continue
  pre=$(sed -n 's/^pre_ticks //p' "out/trace_ref/$name.txt" 2>/dev/null)
  ./out/sf2000/host/trace_fixed.exe --seed "$seed" --steps "$steps" --pre "${pre:-0}" --script "$script" \
    --out "out/trace_fixed/$name.txt" > /dev/null 2>&1
done
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-22.04 -e sh $REPO_WSL/build/qemu_traces.sh > "$D/traces_mips.txt" 2>&1
total=$(grep -vc '^#' build/trace_scenarios.txt)
python tools/compare_dumps.py out/trace_fixed out/trace_mips --tol 0 > "$D/traces_cmp.txt" 2>&1
n=$(grep -c "lines, 0 differ" "$D/traces_cmp.txt")
if grep -q "IDENTICAL" "$D/traces_cmp.txt" && [ "$n" -eq "$total" ]; then
  echo "  ok   $n/$total logic traces MIPS = PC (16.16)"
else
  echo "  FAIL logic traces MIPS vs PC:"; cat "$D/traces_cmp.txt" "$D/traces_mips.txt"; fail=1
fi

[ $fail -eq 0 ] && echo "sf2000_mips_test: OK" || { echo "sf2000_mips_test: FAILED"; exit 1; }
