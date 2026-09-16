#!/bin/sh
# Task 6.5: scene draw calls, triangles and shadow casters over a bot session (every 10th step of live play,
# rendered hidden at 640x480), for every shadow mode in the normal and the wide framing.
#   sh build/render_budget.sh [steps=6000] [seed=9]
cd "$(dirname "$0")/.." || exit 1
N=${1:-6000}
SEED=${2:-9}
mkdir -p out/check/budget
: > out/check/budget/stats.txt
for view in "3 -0.15" "3.5 0"; do
  set -- $view
  for mode in full simple off; do
    ./out/pc/bobrhopper.exe --hidden --seed "$SEED" --smoke "$N" --render-stats 10 --shadows "$mode" \
      --view-scale "$1" --view-shift "$2" --shot-dir out/check/budget 2>&1 | grep -E '^render-(stats|kinds) ' >> out/check/budget/stats.txt
  done
done
cat out/check/budget/stats.txt
