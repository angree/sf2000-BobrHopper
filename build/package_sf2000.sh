#!/bin/sh
# C2.7: the SF2000 / GB300 game package  out/sf2000/BobrHopper-SF2000-<version>/  and  .zip
#   KARTA/                                  copy onto the card root (merges with ROMS\ and cores\ there)
#     ROMS/bobrhopper/BobrHopper            the game (30 fps) - FrogUI starts the files in this folder
#     ROMS/bobrhopper/BobrHopper60          the game reported as 60 fps
#     ROMS/bobrhopper/bench                 the logic benchmark (diagnostics)
#     ROMS/bobrhopper;BobrHopper.gba ...    empty stubs for the multicore menu (core "bobrhopper", ROM after ';')
#     ROMS/bobrhopper/data/...              meshes, fonts, images, sounds, music
#     ROMS/bobrhopper/conf/czytaj.txt       settings and the best score are saved in this folder
#   CORE_<variant>/cores/bobrhopper/core_87000000   ONE of the four, matching the console and its menu
#   CZYTAJ.txt (Polish), README.txt (English)
# Refuses cores older than the sources or built with another version string than <version>.
#   sh build/package_sf2000.sh v003
cd "$(dirname "$0")/.." || exit 1
VER=$1
case "$VER" in v[0-9][0-9][0-9]) ;; *) echo "usage: package_sf2000.sh vNNN"; exit 1 ;; esac
NAME=BobrHopper-SF2000-$VER
OUT=out/sf2000/$NAME
VARIANTS="sf2000_mc gb300_mc sf2000_frogui gb300_frogui"

for v in $VARIANTS; do
  core=out/sf2000/core_87000000_$v
  [ -f "$core" ] || { echo "package: missing $core - run sh build/build_sf2000.sh sf2000_core"; exit 1; }
  newer=$(find src apps -newer "$core" -type f | head -1)
  [ -z "$newer" ] || { echo "package: $core is older than $newer - rebuild"; exit 1; }
  grep -aq "$VER" "$core" || { echo "package: $core does not carry version '$VER' (kCoreVersion)"; exit 1; }
done
for f in manifest.txt meshes/chicken.fmesh fonts/retro_24.fnt images/title.tex sounds/chicken_move_0.snd music/title.wav; do
  [ -f "data_sf2000/$f" ] || { echo "package: data_sf2000/$f missing - run sh build/bake_sf2000.sh"; exit 1; }
done

case "$OUT" in out/sf2000/BobrHopper-SF2000-v*) ;; *) echo "package: bad output dir"; exit 1 ;; esac
rm -rf "out/sf2000/BobrHopper-SF2000-$VER" "out/sf2000/BobrHopper-SF2000-$VER.zip"
mkdir -p "$OUT/KARTA/ROMS/bobrhopper/conf"
for rom in BobrHopper BobrHopper60 bench RenderBench; do
  : > "$OUT/KARTA/ROMS/bobrhopper/$rom"
  : > "$OUT/KARTA/ROMS/bobrhopper;$rom.gba"
done
cp -r data_sf2000 "$OUT/KARTA/ROMS/bobrhopper/data"
printf 'Bobr Hopper zapisuje tu ustawienia i rekord (crossy.cfg).\r\nBobr Hopper saves its settings and best score here (crossy.cfg).\r\n' \
  > "$OUT/KARTA/ROMS/bobrhopper/conf/czytaj.txt"
for v in $VARIANTS; do
  mkdir -p "$OUT/CORE_$v/cores/bobrhopper"
  cp "out/sf2000/core_87000000_$v" "$OUT/CORE_$v/cores/bobrhopper/core_87000000"
done

# CRLF text files for Windows users
crlf() { sed 's/$/\r/'; }
crlf > "$OUT/CZYTAJ.txt" <<EOF
Bóbr Hopper dla SF2000 / GB300 - $VER
====================================

1. Skopiuj zawartosc KARTA\\ na karte konsoli (polacz z istniejacymi ROMS\\).
2. Skopiuj JEDEN katalog CORE_*\\cores na karte (polacz z istniejacym cores\\):
     CORE_sf2000_mc       SF2000 z multicore (sf2000_multicore_official)
     CORE_gb300_mc        GB300 z multicore
     CORE_sf2000_frogui   SF2000 z FrogUI
     CORE_gb300_frogui    GB300 V2 z FrogUI
   Na karcie ma byc: cores\\bobrhopper\\core_87000000
3. Uruchom:
     multicore:  z listy gier  bobrhopper;BobrHopper
     FrogUI:     folder bobrhopper, plik BobrHopper
   BobrHopper60 - to samo, zgloszone firmware'owi jako 60 fps; bench - test szybkosci logiki;
   RenderBench - test sposobow rysowania (wyniki w ROMS\\bobrhopper\\renderbench.txt).

Sterowanie: krzyzak skacze (puszczenie przycisku = skok, jak w oryginale), A = skok do przodu / nowa gra,
Start = pauza, Select = ustawienia (na ekranie startowym i po grze), B = wstecz w menu,
Select + L = licznik klatek. Wyjscie z gry: menu firmware'u.

Ustawienia i rekord: ROMS\\bobrhopper\\conf\\crossy.cfg. Log: ROMS\\bobrhopper\\bobrhopper.log,
czasy klatek: ROMS\\bobrhopper\\game_game30.txt, etapy startu: ROMS\\bobrhopper\\stage.txt.
EOF
crlf > "$OUT/README.txt" <<EOF
Bobr Hopper for SF2000 / GB300 - $VER
====================================

1. Copy the contents of KARTA\\ to the console's card (merge with the existing ROMS\\).
2. Copy ONE of the CORE_*\\cores folders to the card (merge with the existing cores\\):
     CORE_sf2000_mc       SF2000 with multicore (sf2000_multicore_official)
     CORE_gb300_mc        GB300 with multicore
     CORE_sf2000_frogui   SF2000 with FrogUI
     CORE_gb300_frogui    GB300 V2 with FrogUI
   The card must then hold cores\\bobrhopper\\core_87000000
3. Start it:
     multicore:  game list entry  bobrhopper;BobrHopper
     FrogUI:     folder bobrhopper, file BobrHopper
   BobrHopper60 is the same game reported to the firmware as 60 fps; bench is a logic speed test;
   RenderBench compares ways of drawing the game (results in ROMS\\bobrhopper\\renderbench.txt).

Controls: D-pad hops (on release, like the original), A = hop forward / new game, Start = pause,
Select = settings (home and game over screens), B = back in menus, Select + L = frame counter.
Leave the game through the firmware menu.

Settings and best score: ROMS\\bobrhopper\\conf\\crossy.cfg. Log: ROMS\\bobrhopper\\bobrhopper.log,
frame timing: ROMS\\bobrhopper\\game_game30.txt, start-up stages: ROMS\\bobrhopper\\stage.txt.
EOF

python - "$OUT" "out/sf2000/$NAME.zip" <<'PY' || exit 1
import os, sys, zipfile
src, dst = sys.argv[1], sys.argv[2]
base = os.path.dirname(src)
with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in sorted(files):
            path = os.path.join(root, f)
            z.write(path, os.path.relpath(path, base).replace(os.sep, "/"))
name = os.path.basename(src)
with zipfile.ZipFile(dst) as z:
    names = set(z.namelist())
required = ["KARTA/ROMS/bobrhopper/BobrHopper", "KARTA/ROMS/bobrhopper/BobrHopper60", "KARTA/ROMS/bobrhopper/bench", "KARTA/ROMS/bobrhopper/RenderBench",
            "KARTA/ROMS/bobrhopper;BobrHopper.gba", "KARTA/ROMS/bobrhopper;BobrHopper60.gba",
            "KARTA/ROMS/bobrhopper/data/manifest.txt", "KARTA/ROMS/bobrhopper/data/music/title.wav",
            "KARTA/ROMS/bobrhopper/conf/czytaj.txt", "CZYTAJ.txt", "README.txt"]
required += [f"CORE_{v}/cores/bobrhopper/core_87000000" for v in ("sf2000_mc", "gb300_mc", "sf2000_frogui", "gb300_frogui")]
missing = [r for r in required if f"{name}/{r}" not in names]
meshes = sum(1 for n in names if n.endswith(".fmesh"))
if missing or meshes < 38:  # O14: the port adds models of its own (the beaver), so this is a floor, not a count
    print("package: zip check FAILED, missing:", missing, "meshes:", meshes)
    sys.exit(1)
print(f"package: zip check ok - {len(names)} files, 38 meshes, 4 cores, {os.path.getsize(dst) / 1024 / 1024:.1f} MB")
PY
echo "package: $OUT and $OUT.zip"
