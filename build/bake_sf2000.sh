#!/bin/sh
# Regenerates data_sf2000/ (the SF2000 package's data) from the pristine upstream tarball. Run from Git Bash.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
SRC=upstream/expo-crossy-road/assets
if [ ! -d "$SRC" ]; then
  mkdir -p upstream && tar -xzf upstream/expo-crossy-road-6f2e84e5.tar.gz -C upstream
fi
mkdir -p data_sf2000/meshes
python tools/bake_flat.py --all "$SRC" data_sf2000
# textured meshes for the render benchmark only (RenderBench ROM): the R36S meshes from data/ (sh build/bake_all.sh)
[ -d data/meshes ] && python tools/bake_tmesh.py --all "$SRC" data data_sf2000
python tools/write_manifest.py data_sf2000/manifest.txt
# fonts at half the R36S sizes (TextRenderer.glyphScale 2: the 640x480 layouts drawn on 320x240); screen images as on
# the R36S, drawn at half size by the renderer
[ -d data/images ] || { echo "bake_sf2000: run build/bake_all.sh first (data/images)"; exit 1; }
rm -rf data_sf2000/fonts data_sf2000/images data_sf2000/sounds
python tools/bake_font.py --all "$SRC" data_sf2000 --sizes 6,7,8,9,16,24
cp -r data/images data_sf2000/images
# sound effects: the same 22050 Hz PCM as the R36S; music: MS ADPCM .wav instead of Ogg Vorbis (no float on the SF2000)
[ -d data/sounds ] || { echo "bake_sf2000: run build/bake_all.sh first (data/sounds)"; exit 1; }
cp -r data/sounds data_sf2000/sounds
python tools/bake_music_adpcm.py --all Music data_sf2000
echo "bake_sf2000: $(find data_sf2000 -type f | wc -l) files, $(du -sh data_sf2000 | cut -f1)"
