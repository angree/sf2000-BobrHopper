#!/bin/sh
# S0.5/S0.7/F7/C2.1: the SF2000 core in the PC host - it starts (every start-up stage), finds the data, runs the game
# (the pad starts it, logic steps follow the firmware clock), renders every frame deterministically, and the diagnostic
# modes still work: the screen mode runs no logic and the full-speed bench reaches the 16.16 reference digest.
#   sh build/host_smoke.sh      (needs data_sf2000/ from build/bake_sf2000.sh)
cd "$(dirname "$0")/.." || exit 1
EXE=./out/sf2000/host/sf2000_host.exe
D=out/check/host_smoke
CARD=out/sf2000/hostcard/ROMS/bobrhopper
[ -f data_sf2000/manifest.txt ] && [ -d data_sf2000/fonts ] && [ -f data_sf2000/music/title.wav ] || { echo "host_smoke: no data_sf2000 - run sh build/bake_sf2000.sh"; exit 1; }
mkdir -p "$D" "$CARD"
for rom in start start60 bench screen; do : > "$CARD/$rom"; done
# the card's data folder is rebuilt from data_sf2000 on every run
rm -rf out/sf2000/hostcard/ROMS/bobrhopper/data
cp -r data_sf2000 out/sf2000/hostcard/ROMS/bobrhopper/data
rm -f out/sf2000/hostcard/ROMS/bobrhopper/bench_bench.txt out/sf2000/hostcard/ROMS/bobrhopper/stage.txt \
  out/sf2000/hostcard/ROMS/bobrhopper/game_game30.txt out/sf2000/hostcard/ROMS/bobrhopper/game_game60.txt

fail=0
ok() { echo "  ok   $1"; }
bad() { echo "  FAIL $1"; fail=1; }
# every game run starts without saved settings or best score (a best score changes the HUD, and so the frame hash)
clean_conf() {
  rm -f out/sf2000/hostcard/ROMS/bobrhopper/conf/crossy.cfg out/sf2000/hostcard/ROMS/bobrhopper/conf/crossy.cfg.tmp \
    out/sf2000/hostcard/ROMS/bobrhopper/crossy.cfg out/sf2000/hostcard/ROMS/bobrhopper/crossy.cfg.tmp
}
mkdir -p "$CARD/conf"
clean_conf

# the game: A pressed at frame 40 for 4 frames (released = the first hop), then play on
SCRIPT="w40 hold:a:4 w30 shot:after_start w20 hold:up:2 w20 shot:hopped"
"$EXE" --frames 150 --rom "$CARD/start" --shot-dir "$D" --shot-prefix run1 --script "$SCRIPT" --record "$D/run1.pad" > "$D/run1.txt" 2>&1
rc1=$?
clean_conf
"$EXE" --frames 150 --rom "$CARD/start" --shot-dir "$D" --shot-prefix run2 --script "$SCRIPT" > "$D/run2.txt" 2>&1
rc2=$?
clean_conf
# read now: later runs of the start ROM rewrite game_game30.txt
steps30=$(sed -n 's/^frames 150 steps \([0-9]*\) dropped_steps 0$/\1/p' "$CARD/game_game30.txt" 2>/dev/null)
line30=$(sed -n 3p "$CARD/game_game30.txt" 2>/dev/null)

[ $rc1 -eq 0 ] && [ $rc2 -eq 0 ] && ok "both runs exit 0" || bad "exit codes $rc1 $rc2"
for s in 1 2 3 4 5 6 7 8 9; do
  grep -q "stage $s " "$D/run1.txt" && ok "stage $s logged" || bad "stage $s missing"
done
grep -q "manifest=1" "$D/run1.txt" && ok "manifest found through dataDir()" || bad "manifest not found"
grep -q "mode=game30 fps=30" "$D/run1.txt" && ok "ROM start: game30 mode" || bad "start ROM mode"
grep -q "stage 8 game ok" "$D/run1.txt" && ok "game data loaded (meshes, fonts, images)" || bad "game load: $(grep -E 'stage 98|failed' "$D/run1.txt")"
# C2.6: the game's log on the card, flushed after loading and at the end
grep -q "^BobrHopper v" "$CARD/bobrhopper.log" 2>/dev/null && grep -q "^load: ok" "$CARD/bobrhopper.log" && grep -q "^unload after 150 frames" "$CARD/bobrhopper.log" \
  && ok "bobrhopper.log on the card: version, load, unload" || bad "bobrhopper.log: $(head -3 "$CARD/bobrhopper.log" 2>/dev/null)"
grep -q "fs_sync .*bobrhopper.log" "$D/run1.txt" && ok "bobrhopper.log flushed with fs_sync" || bad "no fs_sync for bobrhopper.log"
grep -q "buttons 0100 at frame 40" "$D/run1.txt" && ok "A held from frame 40 reached the core" || bad "A press not seen"
grep -q "state 1 at step" "$D/run1.txt" && ok "the game started playing after A" || bad "state never became Playing"
grep -q "frames=150 video=150" "$D/run1.txt" && ok "150 frames rendered" || bad "frame count"
# O3.1: audio follows the clock, not the call count: 149 calls after the first x 33 ms x 22.05 samples/ms
grep -q "audio_frames=108419" "$D/run1.txt" && ok "audio frames follow the clock at 33 ms per call" || bad "audio frame count: $(grep -o 'audio_frames=[0-9]*' "$D/run1.txt")"
[ -f "$D/run1_after_start.png" ] && [ -f "$D/run1_hopped.png" ] && ok "script shots written" || bad "script shots missing"
h1=$(grep -o 'hash=[0-9a-f]*' "$D/run1.txt")
h2=$(grep -o 'hash=[0-9a-f]*' "$D/run2.txt")
[ -n "$h1" ] && [ "$h1" = "$h2" ] && ok "same frame hash twice ($h1)" || bad "frame hashes differ: $h1 / $h2"
cmp -s "$D/run1_hopped.png" "$D/run2_hopped.png" && ok "identical shots" || bad "shots differ"
# C2.3: sound effects and the streamed music reach audio_batch_cb, the same samples twice
a1=$(grep -o 'audio_fnv=[0-9a-f]*' "$D/run1.txt")
a2=$(grep -o 'audio_fnv=[0-9a-f]*' "$D/run2.txt")
nz=$(sed -n 's/.*audio_nonzero=\([0-9]*\).*/\1/p' "$D/run1.txt")
[ -n "$a1" ] && [ "$a1" = "$a2" ] && ok "same audio samples twice ($a1)" || bad "audio differs: $a1 / $a2"
[ -n "$nz" ] && [ "$nz" -gt 100000 ] && ok "music and sounds audible ($nz non-zero samples)" || bad "audio silent: $nz non-zero samples"
cmp -s "$D/run1_after_start.png" "$D/run1_hopped.png" && bad "the picture did not change after a hop" || ok "the picture changes during play"
# C2.2: the pad recorded per retro_run plays the same game back
"$EXE" --frames 150 --rom "$CARD/start" --shot-dir "$D" --shot-prefix replay --replay "$D/run1.pad" > "$D/replay.txt" 2>&1
hr=$(grep -o 'hash=[0-9a-f]*' "$D/replay.txt")
grep -q "recorded 150 frames" "$D/run1.txt" && [ "$hr" = "$h1" ] && ok "recorded pad replays the same frames ($hr)" || bad "replay hash $hr vs $h1"
clean_conf

# C2.4: a setting changed in the menu reaches the card (flushed with fs_sync) and comes back on the next start
"$EXE" --frames 60 --rom "$CARD/start" --shot-dir "$D" --shot-prefix settings --script "w30 btn:select w10 btn:left w10 shot:settings" > "$D/settings.txt" 2>&1
grep -q "^volume=9" "$CARD/conf/crossy.cfg" 2>/dev/null && ok "SOUNDS lowered in the menu saved as volume=9" || bad "conf/crossy.cfg: $(cat "$CARD/conf/crossy.cfg" 2>/dev/null)"
grep -q "fs_sync .*conf/crossy.cfg" "$D/settings.txt" && ok "the settings file is flushed with fs_sync" || bad "no fs_sync for conf/crossy.cfg"
"$EXE" --frames 5 --rom "$CARD/start" --shot-dir "$D" --shot-prefix reload > "$D/reload.txt" 2>&1
grep -q "settings loaded volume=9" "$D/reload.txt" && ok "the next start loads volume=9" || bad "reload: $(grep 'settings loaded' "$D/reload.txt")"
clean_conf
# O4.1: the run above left the settings screen open (saved on unload); closed with B, the settings reach the card
# before the game is unloaded, and only once for several presses
"$EXE" --frames 90 --rom "$CARD/start" --shot-dir "$D" --shot-prefix settings_b --script "w30 btn:select w10 btn:left w6 btn:left w6 btn:left w10 btn:b w20" > "$D/settings_b.txt" 2>&1
syncs_before_unload=$(sed '/stage 91 retro_unload_game/q' "$D/settings_b.txt" | grep -c "fs_sync .*conf/crossy.cfg$")
grep -q "^volume=7" "$CARD/conf/crossy.cfg" 2>/dev/null && [ "$syncs_before_unload" -eq 1 ] \
  && ok "settings closed with B: written once before unload (volume=7)" || bad "settings on close: $syncs_before_unload syncs before unload, $(grep '^volume' "$CARD/conf/crossy.cfg" 2>/dev/null)"
clean_conf
# 150 calls x 33 ms of firmware clock = 4950 ms = 297 logic steps (+1 on the first call)
[ -n "$steps30" ] && [ "$steps30" -ge 290 ] && [ "$steps30" -le 300 ] && ok "logic follows the clock: $steps30 steps in 150 frames at 33 ms" || bad "game30 steps: $line30"

"$EXE" --frames 60 --tick-ms 17 --rom "$CARD/start60" --shot-dir "$D" --shot-prefix game60 > "$D/game60.txt" 2>&1
# 59 calls after the first x 17 ms x 22.05 samples/ms
grep -q "audio_frames=22116" "$D/game60.txt" && ok "start60 ROM: 60 fps, audio frames follow the clock at 17 ms" || bad "60 fps audio frame count: $(grep -o 'audio_frames=[0-9]*' "$D/game60.txt")"
steps=$(sed -n 's/^frames 60 steps \([0-9]*\) dropped_steps 0$/\1/p' "$CARD/game_game60.txt" 2>/dev/null)
[ -n "$steps" ] && [ "$steps" -ge 58 ] && [ "$steps" -le 62 ] && ok "game60: ~1 logic step per retro_run at 17 ms ($steps)" || bad "game60 steps: $(sed -n 3p "$CARD/game_game60.txt" 2>/dev/null)"

# O3.1: a slow console (55 ms per call, ~18 fps like v003 on the device): the sound still gets 22050 samples a second
# (59 x 55 x 22.05) and the logic still 60 steps a second (59 x 55 x 60 / 1000 = 194.7, +1 on the first call)
"$EXE" --frames 60 --tick-ms 55 --rom "$CARD/start" --shot-dir "$D" --shot-prefix slow > "$D/slow.txt" 2>&1
grep -q "audio_frames=71552" "$D/slow.txt" && ok "slow console (55 ms): audio frames follow the clock" || bad "slow audio frame count: $(grep -o 'audio_frames=[0-9]*' "$D/slow.txt")"
steps=$(sed -n 's/^frames 60 steps \([0-9]*\) dropped_steps 0$/\1/p' "$CARD/game_game30.txt" 2>/dev/null)
[ -n "$steps" ] && [ "$steps" -ge 194 ] && [ "$steps" -le 197 ] && ok "slow console: 60 logic steps a second ($steps)" || bad "slow steps: $(sed -n 3p "$CARD/game_game30.txt" 2>/dev/null)"
clean_conf
# v005: a long gap (600 ms per call, like the console's 448 ms first frame) never hands the firmware more than 2048
# audio frames in one call (v004 sent 5512 and froze the SF2000): calls 2-5 send 2048 each
"$EXE" --frames 5 --tick-ms 600 --rom "$CARD/start" --shot-dir "$D" --shot-prefix gap > "$D/gap.txt" 2>&1
grep -q "audio_frames=8192 " "$D/gap.txt" && ok "long gaps: at most 2048 audio frames per call" || bad "gap audio frames: $(grep -o 'audio_frames=[0-9]*' "$D/gap.txt")"
clean_conf

"$EXE" --frames 30 --rom "$CARD/screen" --shot-dir "$D" --shot-prefix screen > "$D/screen.txt" 2>&1
grep -q "frames=30 video=30" "$D/screen.txt" && ok "screen mode: 30 frames" || bad "screen mode frames"

# the full-speed bench: 200 steps per retro_run -> 20000 steps after 100 calls, results one second later
"$EXE" --frames 140 --rom "$CARD/bench" --shot-dir "$D" --shot-prefix bench > "$D/bench.txt" 2>&1
grep -q "stage 10 bench done digest ok" "$D/bench.txt" && ok "stage 10: bench done, digest ok" || bad "stage 10: $(grep 'stage 10' "$D/bench.txt")"
if grep -q "digest 8eefa860b4ab642d expected 8eefa860b4ab642d ok" "$CARD/bench_bench.txt" 2>/dev/null; then
  ok "bench_bench.txt: 16.16 logic digest after 20000 steps = reference"
else
  bad "bench digest: $(sed -n 3p "$CARD/bench_bench.txt" 2>/dev/null)"
fi
# stage.txt is rewritten at every stage; after a clean exit it holds retro_deinit
grep -q "stage 90 retro_deinit" "$CARD/stage.txt" 2>/dev/null && ok "stage.txt on the card holds the last stage" || bad "stage.txt: $(sed -n 3p "$CARD/stage.txt" 2>/dev/null)"

[ $fail -eq 0 ] && echo "host_smoke: OK" || { echo "host_smoke: FAILED"; tail -20 "$D/run1.txt"; exit 1; }
