#!/usr/bin/env python3
"""Generate the legacy launcher PNGs from the ThinkTac logo SVG.

minSdk is 24, so API 24 and 25 devices are in scope and they predate adaptive
icons. Those launchers read mipmap-*/ic_launcher.png directly and apply no mask,
so unlike the adaptive layers these PNGs have to BE the finished circle rather
than a square that something else crops.

One-shot generator, not a build step, for the same reason as
svg_to_vector_drawable.py: the logo changes about never, and a checked-in asset
is reviewable where a build-time rasteriser is not. Needs ImageMagick once, at
generation time. The output is committed, so nobody else has to install it.
"""
import os, subprocess, tempfile

SRC  = 'assets/images/thinktacLogo_white.svg'
RES  = 'android/app/src/main/res'
NAVY = '#1E2258'   # keep in step with res/values/colors.xml -> tc_launch_navy
SS   = 4           # supersample, downsampled once at the end so edges stay smooth

# The adaptive foreground puts a 60.7dp mark inside a 72dp visible mask, ie the
# mark spans 84% of what you actually see. Matching that here keeps the two
# icons the same visual weight; 0.82 buys a little margin off the circle edge.
MARK = 0.82

DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}


def run(*args):
    subprocess.run(args, check=True, capture_output=True)


with tempfile.TemporaryDirectory() as tmp:
    for density, size in sorted(DENSITIES.items(), key=lambda kv: kv[1]):
        big, mark = size * SS, round(size * SS * MARK)
        fg, circle, flat = (os.path.join(tmp, n) for n in ('fg.png', 'circle.png', 'flat.png'))

        run('convert', '-background', 'none', '-density', '1200', SRC,
            '-resize', f'{mark}x{mark}', fg)
        c = (big - 1) / 2
        run('convert', '-size', f'{big}x{big}', 'xc:none',
            '-fill', NAVY, '-draw', f'circle {c},{c} {c},0', circle)
        run('convert', circle, fg, '-gravity', 'center', '-composite', flat)

        out_dir = f'{RES}/mipmap-{density}'
        os.makedirs(out_dir, exist_ok=True)
        for name in ('ic_launcher.png', 'ic_launcher_round.png'):
            dest = f'{out_dir}/{name}'
            run('convert', flat, '-filter', 'Lanczos', '-resize', f'{size}x{size}',
                '-strip', dest)
            print(f'wrote {dest}  ({size}x{size})')
