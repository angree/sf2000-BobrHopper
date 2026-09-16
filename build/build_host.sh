#!/bin/sh
# The SF2000 core inside apps/sf2000_host.cpp, built with zig from Git Bash:
#   sh build/build_host.sh          -> out/sf2000/host/sf2000_host.exe     (x86_64 Windows, fast)
#   sh build/build_host.sh mipsel   -> out/sf2000/host/sf2000_host.mipsel  (MIPS32 soft-float Linux, run under qemu)
# Both compile the core with CR_PLATFORM_SF2000, like the device build.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd -W)
TOOLS=${CROSSY_TOOLS:-$(cygpath -m "$LOCALAPPDATA")/BobrHopper/tools}
ZIG="$TOOLS/zig-x86_64-windows-0.14.1/zig.exe"
OUT="$ROOT/out/sf2000/host"
KIND=${1:-pc}
[ -x "$ZIG" ] || { echo "missing zig in $TOOLS: run sh build/setup_tools.sh"; exit 1; }
mkdir -p "$OUT"
cd "$ROOT"
python tools/font_to_header.py data/fonts/retro_12.fnt out/sf2000/gen/boot_font.h

. "$ROOT/build/sources.sh"
SOURCES=$(sources_for sf2000_host)
SRC_ABS=""
for s in $SOURCES; do SRC_ABS="$SRC_ABS $ROOT/$s"; done

COMMON="-std=c++17 -O2 -g0 -Wall -ffp-contract=off -DCR_PLATFORM_SF2000 -DCR_FIXED -I$ROOT/src -I$ROOT/third_party/libretro -I$ROOT/out/sf2000/gen"
case "$KIND" in
  pc)
    "$ZIG" c++ -target x86_64-windows-gnu $COMMON $SRC_ABS -o "$OUT/sf2000_host.exe"
    echo "built $OUT/sf2000_host.exe" ;;
  mipsel)
    "$ZIG" c++ -target mipsel-linux-musleabi -mcpu=mips32 -msoft-float -static $COMMON $SRC_ABS -o "$OUT/sf2000_host.mipsel"
    echo "built $OUT/sf2000_host.mipsel" ;;
  pc-trace)
    # the logic trace tool (apps/trace.cpp) with 16.16 on the PC: out/sf2000/host/trace_fixed.exe
    TRACE_ABS=""
    for s in $(sources_for trace_nosdl); do TRACE_ABS="$TRACE_ABS $ROOT/$s"; done
    "$ZIG" c++ -target x86_64-windows-gnu $COMMON $TRACE_ABS -o "$OUT/trace_fixed.exe"
    echo "built $OUT/trace_fixed.exe" ;;
  mipsel-trace)
    # the logic trace tool (apps/trace.cpp) as MIPS32 soft-float, for build/qemu_traces.sh
    TRACE_ABS=""
    for s in $(sources_for trace_nosdl); do TRACE_ABS="$TRACE_ABS $ROOT/$s"; done
    "$ZIG" c++ -target mipsel-linux-musleabi -mcpu=mips32 -msoft-float -static $COMMON $TRACE_ABS -o "$OUT/trace.mipsel"
    echo "built $OUT/trace.mipsel" ;;
  mipsel-swgame)
    # the software renderer benchmark (apps/sw_game.cpp) as MIPS32 soft-float, for build/sw_bench_mips.sh under qemu:
    # emulation time follows the guest's instructions, so it ranks MIPS costs (64-bit divisions, multiplies) that the
    # x86 host hides
    SWG_ABS=""
    for s in $(sources_for sw_game); do SWG_ABS="$SWG_ABS $ROOT/$s"; done
    "$ZIG" c++ -target mipsel-linux-musleabi -mcpu=mips32 -msoft-float -static $COMMON $SWG_ABS -o "$OUT/sw_game.mipsel"
    echo "built $OUT/sw_game.mipsel" ;;
  *) echo "usage: build_host.sh [pc|mipsel|mipsel-trace|pc-trace|mipsel-swgame]"; exit 1 ;;
esac
