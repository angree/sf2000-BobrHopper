#!/bin/sh
# R1.5/R1.6: the SF2000 software SceneRenderer (out/pc/sw_game.exe, 16.16 logic) against the GLES build
# (out/pc/bobrhopper.exe, double logic) in the same scenario frames at 320x240, compared in RGB565.
# The two logics differ by rounding (F6: events within +-2 ticks), so moving objects may sit a pixel or two apart.
#   sh build/sw_scene_compare.sh [view-scale] [view-shift] [shadows full|simple|off]
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
SCALE=${1:-6}
SHIFT=${2:--0.15}
SHADOWS=${3:-off}

# scenario|steps to capture
SHOTS="basic_s3|100,300
car_cross_s26|60,90
hop_every20_s2|150,300
train_wait_s7|140,270
sideways_s6|120,200"

mkdir -p out/check/sw_scene/ref out/check/sw_scene/port out/check/sw_scene/diff
echo "$SHOTS" | while IFS='|' read -r name steps; do
  last=${steps##*,}
  ./out/pc/bobrhopper.exe --hidden --scenario "$name" --frames "$last" --shots "$steps" --shot-prefix "$name" \
    --shot-dir out/check/sw_scene/ref --size 320x240 --view-scale "$SCALE" --view-shift "$SHIFT" --shadows "$SHADOWS" \
    --character chicken --no-hud >/dev/null 2>&1
  ./out/pc/sw_game.exe --scenario "$name" --frames "$last" --shots "$steps" --shot-prefix "$name" \
    --shot-dir out/check/sw_scene/port --size 320x240 --view-scale "$SCALE" --view-shift "$SHIFT" --shadows "$SHADOWS"
done
rm -f out/check/sw_scene/ref/final.png
python tools/compare_images.py out/check/sw_scene/ref out/check/sw_scene/port --rgb565 --diff out/check/sw_scene/diff \
  --max-mean 99 --max-over 100
