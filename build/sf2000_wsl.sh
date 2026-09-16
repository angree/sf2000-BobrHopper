#!/bin/sh
# Runs inside WSL (called by build/build_sf2000.sh): compiles a target's sources with the SF2000 multicore toolchain
# and flags into out/sf2000/obj/<target>/ and archives them as out/sf2000/lib<target>.a.
# For sf2000_core it then links the archive into the FOUR device variants, the way QPSX_400 does
# (the same way the QPSX core links: build_*_mc.bat, link_multicore.sh):
#   sf2000_mc      Temp/sf2000_multicore_official   bisrv_08_03-core.ld
#   gb300_mc       Temp/gb300_multicore             bisrv_08_03-core.ld (its own)
#   sf2000_frogui  Temp_FrogUI/sf2000_multicore     linker_scripts/bisrv_08_03-core.ld     -DSF2000 -DFROGGY_MXMV=0x60
#   gb300_frogui   Temp_FrogUI/sf2000_multicore     linker_scripts/bisrv_GB300_V2-core.ld  -DGB300V2 -DFROGGY_MXMV=0x28
# The frameworks' wrapper sources (core_api.c lib.c debug.c video_sf2000.c) are compiled from the user's checkouts
# into out/sf2000/variants/<variant>/ - the checkouts are only read, never written.
# Result: out/sf2000/core_87000000_<variant> (+ variants/<variant>/core.elf.map).
# Usage: sf2000_wsl.sh <target> [variant...]   (sf2000_core without variants = all four)
# Every run rebuilds every object (no header dependency tracking to get wrong; the whole game is ~25 files).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BASE=${SF2000_BASE_ROOT:-}
[ -n "$BASE" ] || { echo "sf2000: set SF2000_BASE_ROOT to the folder holding the multicore framework checkouts (see README.md)"; exit 1; }
TARGET=${1:-sf2000_core}
[ $# -gt 0 ] && shift
VARIANTS=${*:-sf2000_mc gb300_mc sf2000_frogui gb300_frogui}
for d in /opt/mips32-mti-elf/2019.09-03-2/bin /tmp/mips32-mti-elf/2019.09-03-2/bin; do
  if [ -x "$d/mips-mti-elf-g++" ]; then TC=$d; break; fi
done
[ -n "$TC" ] || { echo "sf2000: mips-mti-elf toolchain not found in /opt or /tmp"; exit 1; }
CC="$TC/mips-mti-elf-gcc"
CXX="$TC/mips-mti-elf-g++"
AR="$TC/mips-mti-elf-ar"
OBJCOPY="$TC/mips-mti-elf-objcopy"

cd "$ROOT" || exit 1
. build/sources.sh
SOURCES=$(sources_for "$TARGET") || { echo "sf2000: unknown target $TARGET"; exit 1; }

# the multicore framework's flags (Makefile CFLAGS), C++17 without exceptions/RTTI;
# gnu++17, not c++17: newlib hides the C99 stdio functions (snprintf, vsnprintf) under __STRICT_ANSI__
ARCH="-EL -march=mips32 -mtune=mips32 -msoft-float"
BASEFLAGS="$ARCH -G0 -mno-abicalls -fno-pic -ffunction-sections -fdata-sections"
FLAGS="$BASEFLAGS -std=gnu++17 -O2 -Wall -ffp-contract=off -fno-exceptions -fno-rtti -DCR_PLATFORM_SF2000 -DCR_FIXED"
FLAGS="$FLAGS -Isrc -Ithird_party/libretro -Iout/sf2000/gen"

OBJ="out/sf2000/obj/$TARGET"
mkdir -p "$OBJ"
rm -f out/sf2000/obj/"$TARGET"/*.o
LOG="out/sf2000/$TARGET.log"
: > "$LOG"
echo "sf2000: $CXX ($($CXX -dumpversion)) target $TARGET"

fail=0
for s in $SOURCES; do
  o="$OBJ/$(echo "$s" | tr '/' '_' | sed 's/\.cpp$/.o/')"
  echo "$s" >> "$LOG"
  $CXX $FLAGS -c "$s" -o "$o" >> "$LOG" 2>&1 &
done
wait
for s in $SOURCES; do
  o="$OBJ/$(echo "$s" | tr '/' '_' | sed 's/\.cpp$/.o/')"
  [ -f "$o" ] || { echo "sf2000: FAILED $s"; fail=1; }
done
grep -E "error|warning" "$LOG" | grep -v "stb_vorbis.c" | head -40
[ $fail -eq 0 ] || { echo "sf2000: compile failed, full log in $LOG"; exit 1; }

LIB="out/sf2000/lib$TARGET.a"
rm -f "$LIB"
$AR rcs "$LIB" "$OBJ"/*.o || exit 1
echo "sf2000: built $LIB ($(ls "$OBJ"/*.o | wc -l) objects, $(stat -c %s "$LIB") bytes)"

[ "$TARGET" = "sf2000_core" ] || exit 0

# ---- link one variant: framework wrappers from source, then core.elf -> core_87000000 like the framework Makefile
link_variant() {
  v=$1
  case "$v" in
    sf2000_mc)     FW="$BASE/Temp/sf2000_multicore_official"; LDDIR="$FW"; CORE_LD=bisrv_08_03-core.ld; PFLAGS="" ;;
    gb300_mc)      FW="$BASE/Temp/gb300_multicore"; LDDIR="$FW"; CORE_LD=bisrv_08_03-core.ld; PFLAGS="" ;;
    sf2000_frogui) FW="$BASE/Temp_FrogUI/sf2000_multicore"; LDDIR="$FW/linker_scripts"; CORE_LD=bisrv_08_03-core.ld
                   PFLAGS="-DSF2000 -DFROGGY_MXMV=0x60" ;;
    gb300_frogui)  FW="$BASE/Temp_FrogUI/sf2000_multicore"; LDDIR="$FW/linker_scripts"; CORE_LD=bisrv_GB300_V2-core.ld
                   PFLAGS="-DGB300V2 -DFROGGY_MXMV=0x28" ;;
    *) echo "sf2000: unknown variant $v"; return 1 ;;
  esac
  VD="out/sf2000/variants/$v"
  VLOG="$VD/link.log"
  mkdir -p "$VD"
  rm -f "$VD"/*.o "$VD/core.elf" "$VD/core.elf.map" "$VD/core_87000000" "out/sf2000/core_87000000_$v"
  : > "$VLOG"
  for f in core_api.c lib.c debug.c video_sf2000.c; do
    [ -f "$FW/$f" ] || { echo "sf2000: $v: missing $FW/$f"; return 1; }
  done
  for f in "$LDDIR/core.ld" "$LDDIR/$CORE_LD" "$FW/libs/libretro-common/libretro-common.a"; do
    [ -f "$f" ] || { echo "sf2000: $v: missing $f"; return 1; }
  done
  WFLAGS="$BASEFLAGS -Os -I$FW -I$FW/libs/libretro-common/include -DDEBUG_XLOG=1 $PFLAGS"
  for f in core_api lib debug video_sf2000; do
    $CC $WFLAGS -c "$FW/$f.c" -o "$VD/$f.o" >> "$VLOG" 2>&1 || { grep -E "error" "$VLOG" | head; echo "sf2000: $v: $f.c failed"; return 1; }
  done
  $CXX -Wl,-Map="$VD/core.elf.map" $ARCH -Wl,--gc-sections --static -z max-page-size=32 \
    -e __core_entry__ -T"$LDDIR/core.ld" "$LDDIR/$CORE_LD" -o "$VD/core.elf" \
    -Wl,--start-group "$VD/core_api.o" "$VD/lib.o" "$VD/debug.o" "$VD/video_sf2000.o" "$LIB" \
    "$FW/libs/libretro-common/libretro-common.a" -lc -Wl,--end-group >> "$VLOG" 2>&1
  if [ ! -f "$VD/core.elf" ]; then
    grep -E "undefined|error|multiple" "$VLOG" | head -20
    echo "sf2000: $v: link failed, log in $VLOG"
    return 1
  fi
  $OBJCOPY -O binary -R .MIPS.abiflags -R .note.gnu.build-id -R ".rel*" "$VD/core.elf" "$VD/core_87000000" || return 1
  # the core is loaded at 0x87000000 and its image + .bss must stay inside the 128 MB of RAM (below 0x88000000)
  END=$(grep -E "^ +0x[0-9a-f]+ +_end = \." "$VD/core.elf.map" | awk '{print $1}' | tail -1)
  [ -n "$END" ] || { echo "sf2000: $v: _end not found in the map"; return 1; }
  if [ $((END)) -ge $((0x88000000)) ]; then
    echo "sf2000: $v: _end $END is past 0x88000000 - the core does not fit"
    return 1
  fi
  ENTRY=$($TC/mips-mti-elf-nm "$VD/core.elf" | grep " T __core_entry__" | awk '{print $1}')
  case "$ENTRY" in *87000000) ;; *) echo "sf2000: $v: __core_entry__ at $ENTRY, not 0x87000000"; return 1 ;; esac
  cp "$VD/core_87000000" "out/sf2000/core_87000000_$v"
  echo "sf2000: built out/sf2000/core_87000000_$v ($(stat -c %s "$VD/core_87000000") bytes, _end $END)"
}

vfail=0
for v in $VARIANTS; do
  link_variant "$v" || vfail=1
done
[ $vfail -eq 0 ] || { echo "sf2000: some variants failed"; exit 1; }
