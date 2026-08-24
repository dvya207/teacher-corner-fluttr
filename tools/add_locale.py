#!/usr/bin/env python3
"""Writes a locale file with the same shape as en.json, and refuses to write a
partial one.

Why a tool rather than hand-editing JSON: en.json is nested, the translations are
authored flat (key paths), and a missing key is invisible in review but shows up
as English text in the middle of a Marathi screen. This fails loudly instead.

Usage (from the repo root):
    python3 tools/add_locale.py <code> <flat-json-file>

The flat file is {"auth.send_otp": "...", ...}. Every key in en.json must be
present; extras are an error too, because they are usually a typo in a key path.
"""
import json
import sys
from collections import OrderedDict

EN = 'assets/l10n/en.json'


def flatten(d, prefix=''):
    out = OrderedDict()
    for k, v in d.items():
        if isinstance(v, dict):
            out.update(flatten(v, prefix + k + '.'))
        else:
            out[prefix + k] = v
    return out


def nest(flat):
    """Rebuilds en.json's nesting from flat key paths, preserving its order."""
    out = OrderedDict()
    for path, value in flat.items():
        parts = path.split('.')
        cursor = out
        for part in parts[:-1]:
            cursor = cursor.setdefault(part, OrderedDict())
        cursor[parts[-1]] = value
    return out


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2

    code, source = sys.argv[1], sys.argv[2]
    en = flatten(json.load(open(EN), object_pairs_hook=OrderedDict))
    incoming = json.load(open(source), object_pairs_hook=OrderedDict)

    missing = [k for k in en if k not in incoming]
    extra = [k for k in incoming if k not in en]
    if missing or extra:
        for k in missing:
            print(f'MISSING {k}')
        for k in extra:
            print(f'UNKNOWN {k}')
        print(f'\n{len(missing)} missing, {len(extra)} unknown. Nothing written.')
        return 1

    # Placeholder arity must match, or `.tr(args: [...])` silently drops or
    # duplicates a value. Positional {} means ORDER matters as well as count.
    for k, english in en.items():
        if english.count('{}') != incoming[k].count('{}'):
            print(f'PLACEHOLDER MISMATCH {k}: en has {english.count("{}")}, '
                  f'{code} has {incoming[k].count("{}")}')
            return 1

    # Follow en.json's key order exactly, so a diff between two locale files is
    # readable.
    ordered = OrderedDict((k, incoming[k]) for k in en)
    target = f'assets/l10n/{code}.json'
    with open(target, 'w') as f:
        json.dump(nest(ordered), f, indent=2, ensure_ascii=False)
        f.write('\n')
    print(f'wrote {target} ({len(ordered)} keys)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
