#!/bin/sh
# F5: the SF2000 code must not do any float or double arithmetic (docs/PROGRESS.md, user decision after the v001
# bench). With -msoft-float every float operation is a call into libgcc, so an object file that uses one carries a
# relocation to one of these routines. Runs inside WSL:
#   sh build/check_softfloat.sh [object dir]          (default out/sf2000/obj/sf2000_core)
#   sh build/check_softfloat.sh --self-test           (must fail on a deliberately bad file)
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
for d in /opt/mips32-mti-elf/2019.09-03-2/bin /tmp/mips32-mti-elf/2019.09-03-2/bin; do
  if [ -x "$d/mips-mti-elf-objdump" ]; then TC=$d; break; fi
done
[ -n "$TC" ] || { echo "check_softfloat: toolchain not found"; exit 2; }

# libgcc soft-float entry points: arithmetic, comparisons, conversions (single and double precision)
PATTERN='__(add|sub|mul|div|neg)(s|d|t)f3|__(eq|ne|lt|le|gt|ge|unord)(s|d|t)f2|__(fix|fixuns)(s|d|t)f(s|d|t)i|__float(un)?(s|d|t)i(s|d|t)f|__(extend|trunc)(s|d|t)f(s|d|t)f2|__powi(s|d)f2'

scan() { # dir -> prints offending "object: symbol" lines, returns 1 when any
  found=0
  for o in "$1"/*.o; do
    [ -f "$o" ] || continue
    hits=$("$TC/mips-mti-elf-objdump" -r "$o" | grep -E "$PATTERN" | awk '{print $NF}' | sort | uniq -c | tr -s ' ')
    if [ -n "$hits" ]; then
      echo "$(basename "$o"):$hits" | tr '\n' ' '
      echo
      found=1
    fi
  done
  return $found
}

if [ "$1" = "--self-test" ]; then
  T=out/check/softfloat_selftest
  mkdir -p "$T"
  printf 'double scale(double a, int b) { return a * b + 0.5; }\n' > "$T/bad.c"
  printf 'int scale(int a, int b) { return (a * b) >> 16; }\n' > "$T/good.c"
  for f in bad good; do
    "$TC/mips-mti-elf-gcc" -EL -march=mips32 -msoft-float -O2 -G0 -mno-abicalls -fno-pic -c "$T/$f.c" -o "$T/$f.o" || exit 2
  done
  mkdir -p "$T/good_only" "$T/bad_only"
  cp "$T/good.o" "$T/good_only/"
  cp "$T/bad.o" "$T/bad_only/"
  if scan "$T/bad_only" > /dev/null; then echo "check_softfloat self-test: FAILED (bad.o passed)"; exit 1; fi
  if ! scan "$T/good_only" > /dev/null; then echo "check_softfloat self-test: FAILED (good.o rejected)"; exit 1; fi
  echo "check_softfloat self-test: OK (bad.o rejected: $(scan "$T/bad_only"))"
  exit 0
fi

DIR=${1:-out/sf2000/obj/sf2000_core}
n=$(ls "$DIR"/*.o 2>/dev/null | wc -l)
[ "$n" -gt 0 ] || { echo "check_softfloat: no objects in $DIR"; exit 2; }
if out=$(scan "$DIR"); then
  echo "check_softfloat: OK - $n objects in $DIR, no soft-float calls"
  exit 0
fi
echo "check_softfloat: FAILED - soft-float calls in $DIR:"
echo "$out"
exit 1
