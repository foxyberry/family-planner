#!/usr/bin/env python3
"""WCAG contrast ratio of a colour pair. Usage: python3 contrast.py 625D6E FFFFFF [more pairs ...]
Pass marks follow the spec's Contrast rule: body / caption text 4.5 : 1; title size and up and UI
parts 3 : 1."""
import sys


def luminance(hex6):
    channels = [int(hex6[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def main(args):
    pairs = [a.lstrip("#").upper() for a in args]
    if len(pairs) < 2 or len(pairs) % 2 or any(len(p) != 6 for p in pairs):
        print(__doc__)
        return 2
    for fg, bg in zip(pairs[::2], pairs[1::2]):
        a, b = luminance(fg), luminance(bg)
        ratio = (max(a, b) + 0.05) / (min(a, b) + 0.05)
        verdict = "any text" if ratio >= 4.5 else "title and up, UI parts; not body or caption" if ratio >= 3 else "fails"
        print(f"#{fg} on #{bg}: {ratio:.2f} : 1  ({verdict})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
