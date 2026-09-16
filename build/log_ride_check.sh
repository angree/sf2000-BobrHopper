#!/bin/sh
# O16: the hero sitting on a log was drawn UNDER it (user report after v023: "czasem postac sie chowa pod logiem na
# ktorym powinna siedziec"). The SF2000 has no depth buffer and sorts whole objects by the distance of their centre,
# and the camera looks down from -x, so the key is 0.241*x - 0.674*y + 0.698*z. A hero on a log sits only 0.5 above
# the log's centre, which buys it 0.337 of sorting margin - about 1.40 units of x. The logs are up to 3.875 long and
# the collision box lets the hero sit 2.25 from the centre, so a hero towards the +x end of a long log sorted in
# front of its log and the log was drawn over it, leaving only the hero's head visible.
# SceneRenderer::renderScene now pushes the ridden log's items just behind the hero's; sw_game --no-ride-fix turns
# that off. The check renders the same frame three ways and asks for no threshold: with the fix the frame must sit
# closer to the depth-buffered reference (which is right by construction) than without it.
#   sh build/log_ride_check.sh [seeds]       (default 60; needs out/pc/trace.exe and out/pc/sw_game.exe:
#                                             sh build/build_pc.sh trace && sh build/build_pc.sh sw_game)
cd "$(dirname "$0")/.." || exit 1
mkdir -p out/check/log_ride
CR_SEEDS=${1:-60} python - <<'EOF'
import json, os, re, subprocess, sys
from PIL import Image

TRACE = "./out/pc/trace.exe"
SW = "./out/pc/sw_game.exe"
D = "out/check/log_ride"
OUT = D + "/trace.txt"
SEEDS = int(os.environ.get("CR_SEEDS", "60"))
# the sorting margin a hero on a log has, in units of x (see the header); anything beyond it sorted wrongly
THRESHOLD = 1.40
HERO_BOX = (120, 110, 200, 180)  # the camera follows the hero, so it is always around the middle of the frame

rows_re = re.compile(r"^rows (.*)$")
line_re = re.compile(r"t=(\d+) state=(\w+) alive=(\d) moving=(\d) riding=(\d) hit=(\d) hero=([-\d.]+),([-\d.]+),"
                     r"([-\d.]+).*ride=([-\d.]+),(\d+),([-\d.]+)")


def row_types(seed):
    subprocess.run([TRACE, "--seed", str(seed), "--steps", "1", "--script", "w1", "--out", OUT, "--row-types",
                    "--game"], capture_output=True)
    for line in open(OUT):
        m = rows_re.match(line)
        if m:
            return {int(p.split(":")[0]): p.split(":")[1] for p in m.group(1).split()}
    return {}


def worst_ride(seed, script, steps):
    """the frame of this run where the hero sits farthest along its log towards +x"""
    subprocess.run([TRACE, "--seed", str(seed), "--steps", str(steps), "--script", script, "--out", OUT, "--water",
                    "--game"], capture_output=True)
    top = None
    for line in open(OUT):
        m = line_re.match(line)
        if not m:
            continue
        t, _st, alive, moving, riding, _hit, _hx, _hy, _hz, _lx, width, off = m.groups()
        if alive == "1" and riding == "1" and moving == "0":
            o = float(off)
            if top is None or o > top[1]:
                top = (int(t), o, int(width))
    return top


def shot(seed, script, steps, t, prefix, extra):
    subprocess.run([SW, "--seed", str(seed), "--script", script, "--frames", str(steps), "--shots", str(t),
                    "--shot-dir", D, "--shot-prefix", prefix] + extra, capture_output=True)
    return "%s/%s_t%d.png" % (D, prefix, t)


def diff(a, b, box):
    A = Image.open(a).convert("RGB").crop(box)
    B = Image.open(b).convert("RGB").crop(box)
    return sum(1 for y in range(A.height) for x in range(A.width) if A.getpixel((x, y)) != B.getpixel((x, y)))


cases, checked, failures = [], 0, 0
for seed in range(1, SEEDS + 1):
    rt = row_types(seed)
    water = [r for r in sorted(rt) if rt[r] == "water" and r >= 10]
    if not water:
        continue
    W = water[0]
    for wait in (20, 30, 40, 50, 60, 70):
        hops = " ".join(["w%d u" % wait] * (W - 8))
        script = "w20 s w20 " + hops + " w40 r w45 r w45 r w90"
        steps = 60 + (W - 8) * (wait + 8) + 240
        top = worst_ride(seed, script, steps)
        if top and top[1] > THRESHOLD and top[2] >= 3:
            cases.append((seed, script, steps) + top)
            break
    if len(cases) >= 3:
        break

if not cases:
    print("log_ride_check: no hero ever sat more than %.2f along a long log in %d seeds - nothing to check"
          % (THRESHOLD, SEEDS))
    sys.exit(1)

for seed, script, steps, t, off, width in cases:
    fixed = shot(seed, script, steps, t, "fixed_s%d" % seed, [])
    broken = shot(seed, script, steps, t, "broken_s%d" % seed, ["--no-ride-fix"])
    ref = shot(seed, script, steps, t, "ref_s%d" % seed, ["--depth"])
    dFixed, dBroken = diff(fixed, ref, HERO_BOX), diff(broken, ref, HERO_BOX)
    checked += 1
    good = dFixed < dBroken
    if not good:
        failures += 1
    print("  seed %-4d frame %-5d hero %.3f along a width-%d log: painter vs depth reference around the hero - "
          "with the fix %4d px, without it %4d px  %s" % (seed, t, off, width, dFixed, dBroken,
                                                          "ok" if good else "FAILED"))

print("log_ride_check: %d cases, %d closer to the reference with the fix, %d not -> %s"
      % (checked, checked - failures, failures, "FAILED" if failures else "OK"))
sys.exit(1 if failures else 0)
EOF
