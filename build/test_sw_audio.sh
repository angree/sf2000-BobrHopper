#!/bin/sh
# C2.3: the SF2000 audio path on the PC (CR_FIXED) - ffmpeg makes a 3 s MS ADPCM test track (tone + noise) and decodes
# it as the reference, then tests/test_sw_audio.cpp checks our decoder, looping and the mixer against it.
#   sh build/test_sw_audio.sh      (needs data_sf2000/ with sounds: build/bake_sf2000.sh)
cd "$(dirname "$0")/.." || exit 1
mkdir -p out/check/audio
ffmpeg -v error -y -f lavfi -i "sine=frequency=440:duration=3" -f lavfi -i "anoisesrc=d=3:a=0.3:seed=7" \
  -filter_complex "[0][1]amix=inputs=2" -ac 1 -ar 22050 -c:a adpcm_ms -block_size 1024 out/check/audio/tone.wav || exit 1
ffmpeg -v error -y -i out/check/audio/tone.wav -f s16le -acodec pcm_s16le out/check/audio/tone.raw || exit 1
sh build/build_pc.sh test_sw_audio 2>&1 | grep -E "error|warning|built"
./out/pc/test_sw_audio.exe out/check/audio/tone.wav out/check/audio/tone.raw data_sf2000/
