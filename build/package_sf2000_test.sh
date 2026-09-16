#!/bin/sh
# Test package for the SF2000 / GB300 card: out/sf2000/test_<version>/
#   KARTA/                       copy onto the card root (merge with the existing folders)
#     ROMS/bobrhopper;start.gba    stub (0 B, old multicore stub format): core "bobrhopper", ROM "start", 30 fps
#     ROMS/bobrhopper;start60.gba  the same core reporting 60 fps (the core picks it from the ROM name)
#     ROMS/bobrhopper/start, start60, data/...
#   CORE_<variant>/cores/bobrhopper/core_87000000   ONE of the four, for the console + multicore that is on the card
#   CZYTAJ.txt
# Refuses a variant older than the sources.
#   sh build/package_sf2000_test.sh v001
cd "$(dirname "$0")/.." || exit 1
VER=${1:-v001}
OUT=out/sf2000/test_$VER
VARIANTS="sf2000_mc gb300_mc sf2000_frogui gb300_frogui"

for v in $VARIANTS; do
  [ -f "out/sf2000/core_87000000_$v" ] || { echo "package: missing out/sf2000/core_87000000_$v - run sh build/build_sf2000.sh"; exit 1; }
  newer=$(find src apps -newer "out/sf2000/core_87000000_$v" -type f | head -1)
  [ -z "$newer" ] || { echo "package: core_87000000_$v is older than $newer - rebuild"; exit 1; }
done

case "$OUT" in out/sf2000/test_*) ;; *) echo "package: bad output dir"; exit 1 ;; esac
[ -d "$OUT" ] && rm -rf "out/sf2000/test_$VER"
mkdir -p "$OUT/KARTA/ROMS/bobrhopper"
for rom in start start60 bench screen; do
  : > "$OUT/KARTA/ROMS/bobrhopper;$rom.gba"
  : > "$OUT/KARTA/ROMS/bobrhopper/$rom"
done
[ -f data_sf2000/manifest.txt ] && [ -d data_sf2000/fonts ] || { echo "package: no data_sf2000 - run sh build/bake_sf2000.sh"; exit 1; }
cp -r data_sf2000 "$OUT/KARTA/ROMS/bobrhopper/data"
# the core saves settings and the best score here (a file keeps the folder when the package is copied)
mkdir -p "$OUT/KARTA/ROMS/bobrhopper/conf"
printf 'BobrHopper zapisuje tu ustawienia i rekord (crossy.cfg).\r\n' > "$OUT/KARTA/ROMS/bobrhopper/conf/czytaj.txt"
for v in $VARIANTS; do
  mkdir -p "$OUT/CORE_$v/cores/bobrhopper"
  cp "out/sf2000/core_87000000_$v" "$OUT/CORE_$v/cores/bobrhopper/core_87000000"
done

cat > "$OUT/CZYTAJ.txt" <<EOF
BobrHopper SF2000 / GB300 - test rdzenia $VER (logika gry w 16.16, bez float/double)
=====================================================================================

To jeszcze nie gra: ekran diagnostyczny, ktory mierzy na konsoli koszt logiki gry (bez grafiki 3D).

1. Skopiuj zawartosc KARTA\\ na karte (polacz z istniejacymi ROMS\\).
2. Skopiuj JEDEN z katalogow CORE_*\\cores na karte (polacz z istniejacym cores\\):
     CORE_sf2000_mc       SF2000 z multicore (sf2000_multicore_official)
     CORE_gb300_mc        GB300 z multicore (gb300_multicore)
     CORE_sf2000_frogui   SF2000 z FrogUI
     CORE_gb300_frogui    GB300 V2 z FrogUI
   Na karcie ma byc: cores\\bobrhopper\\core_87000000
3. Uruchom po kolei z listy gier (po kazdym wyjdz do menu):
     bobrhopper;screen    sam ekran, bez logiki - czy RUN/S dochodzi do 30
     bobrhopper;start     jak gra przy 30 fps: 2 kroki logiki + przeliczenie sceny na klatke
     bobrhopper;start60   jak gra przy 60 fps: 1 krok + przeliczenie sceny na klatke
     bobrhopper;bench     pelna predkosc do 20000 krokow; na koncu linia z digestem "OK"
   W kazdym poczekaj ok. 20-30 s i zrob zdjecie ekranu (RUN/S, GAP, STEP US, WORLD US).
4. Z karty: ROMS\\bobrhopper\\bench_screen.txt, bench_game30.txt, bench_game60.txt, bench_bench.txt i stage.txt.

Jesli ekran sie zatrzyma: numer "stage" na ekranie i ROMS\\bobrhopper\\stage.txt mowia, gdzie.
EOF
find "$OUT" -type f | wc -l
du -sh "$OUT"
echo "package: $OUT"
