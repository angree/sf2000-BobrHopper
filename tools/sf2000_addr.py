#!/usr/bin/env python3
"""Which function of the SF2000 core an address belongs to (the firmware's exception screen shows the address).

Reads the linker map of a core variant (out/sf2000/variants/<variant>/core.elf.map, written by build/sf2000_wsl.sh):
every `.text.<function>` input section with its start and size; names are demangled with c++filt when it is there.

  python tools/sf2000_addr.py 0x87005e60 [0x8700a010 ...] [--variant sf2000_mc] [--map path/to/core.elf.map]

Prints `address  function+offset  object file` per address, or `outside the core` when no section holds it.
"""
import os
import re
import shutil
import subprocess
import sys

SECTION = re.compile(r"^ (\.text[.\w$@:~<>,*&\[\]-]*)(?:\s+0x([0-9a-f]+)\s+0x([0-9a-f]+)\s+(\S+))?\s*$")
CONTINUATION = re.compile(r"^\s+0x([0-9a-f]+)\s+0x([0-9a-f]+)\s+(\S+)\s*$")


def read_sections(map_path):
    sections = []
    pending = None
    with open(map_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if pending:
                m = CONTINUATION.match(line)
                if m:
                    sections.append((int(m.group(1), 16), int(m.group(2), 16), pending, m.group(3)))
                pending = None
                continue
            m = SECTION.match(line.rstrip("\n"))
            if not m:
                continue
            name = m.group(1)[len(".text."):] if m.group(1).startswith(".text.") else m.group(1)
            if m.group(2):
                sections.append((int(m.group(2), 16), int(m.group(3), 16), name, m.group(4)))
            else:
                pending = name
    return [s for s in sections if s[1] > 0]


def demangle(names):
    """c++filt from the PATH, or Ubuntu's in WSL (Git Bash has none); raw names when neither runs."""
    if not names:
        return {}
    tool = shutil.which("c++filt")
    commands = [[tool]] if tool else []
    if shutil.which("wsl.exe"):
        commands.append(["wsl.exe", "-d", "Ubuntu-22.04", "-e", "c++filt"])
    for command in commands:
        try:
            out = subprocess.run(command, input="\n".join(names) + "\n", capture_output=True, text=True,
                                 timeout=60).stdout.splitlines()
        except (OSError, subprocess.SubprocessError):
            continue
        if len(out) == len(names):
            return dict(zip(names, out))
    return {n: n for n in names}


def lookup(sections, address):
    for start, size, name, obj in sections:
        if start <= address < start + size:
            return name, address - start, obj
    return None


def main(argv):
    variant, map_path, addresses = "sf2000_mc", None, []
    i = 0
    while i < len(argv):
        if argv[i] == "--variant":
            variant = argv[i + 1]
            i += 2
        elif argv[i] == "--map":
            map_path = argv[i + 1]
            i += 2
        else:
            addresses.append(int(argv[i], 16))
            i += 1
    if not addresses:
        print(__doc__)
        return 1
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    map_path = map_path or os.path.join(root, "out", "sf2000", "variants", variant, "core.elf.map")
    if not os.path.exists(map_path):
        print(f"sf2000_addr: no map {map_path} (build the core first)")
        return 1
    sections = read_sections(map_path)
    found = [lookup(sections, a) for a in addresses]
    names = demangle(sorted({f[0] for f in found if f}))
    for address, hit in zip(addresses, found):
        if hit:
            name, offset, obj = hit
            print(f"0x{address:08x}  {names[name]}+0x{offset:x}  {os.path.basename(obj)}")
        else:
            print(f"0x{address:08x}  outside the core")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
