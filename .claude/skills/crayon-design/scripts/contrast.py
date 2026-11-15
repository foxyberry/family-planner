#!/usr/bin/env python3
"""WCAG contrast ratio of a colour pair. Usage: python3 contrast.py 625D6E FFFFFF [more pairs ...]
This app's rule: every text colour needs 4.5 : 1 on its ground (day and night); UI parts and
outlines need 3 : 1. (WCAG allows 3 : 1 for large text; the app holds all text to 4.5 for kids.)"""
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
        verdict = "text ok" if ratio >= 4.5 else "UI parts only, not text" if ratio >= 3 else "fails"
        print(f"#{fg} on #{bg}: {ratio:.2f} : 1  ({verdict})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
