"""Convert the ThinkTac logo SVG into two Android VectorDrawables.

Kept as a one-shot generator rather than a build step: the logo changes about
never, and a checked-in XML is reviewable where a build-time rasteriser is not.
"""
import re, sys

SRC = 'assets/images/thinktacLogo_white.svg'
svg = open(SRC).read()

vb = re.search(r'viewBox="([\d.\s-]+)"', svg).group(1).split()
VW, VH = float(vb[2]), float(vb[3])

paths = []
for tag in re.findall(r'<path\b.*?/?>', svg, re.S):
    fill = re.search(r'fill="([^"]*)"', tag)
    d = re.search(r'\sd="(.*?)"', tag, re.S)
    if not d:
        continue
    # VectorDrawable tolerates whitespace but not newlines/tabs mid-attribute.
    data = re.sub(r'\s+', ' ', d.group(1)).strip()
    paths.append((fill.group(1) if fill else '#FFFFFF', data))

def emit(out, w_dp, h_dp, vw, vh, scale=None, tx=0.0, ty=0.0):
    L = ['<?xml version="1.0" encoding="utf-8"?>',
         '<!-- GENERATED from assets/images/thinktacLogo_white.svg. Do not hand-edit. -->',
         '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
         f'    android:width="{w_dp}dp"',
         f'    android:height="{h_dp}dp"',
         f'    android:viewportWidth="{vw}"',
         f'    android:viewportHeight="{vh}">']
    ind = '    '
    if scale is not None:
        L.append(f'{ind}<group')
        L.append(f'{ind}    android:scaleX="{scale}"')
        L.append(f'{ind}    android:scaleY="{scale}"')
        L.append(f'{ind}    android:translateX="{tx}"')
        L.append(f'{ind}    android:translateY="{ty}">')
        ind = '        '
    for fill, data in paths:
        L.append(f'{ind}<path')
        L.append(f'{ind}    android:fillColor="{fill}"')
        L.append(f'{ind}    android:pathData="{data}" />')
    if scale is not None:
        L.append('    </group>')
    L.append('</vector>')
    open(out, 'w').write('\n'.join(L) + '\n')
    print(f'wrote {out}  ({len(paths)} paths)')

D = 'android/app/src/main/res/drawable'

# 1. The bare logo, for the pre-Android-12 layer-list which sizes it explicitly.
emit(f'{D}/tc_launch_logo.xml', 161, 147, VW, VH)

# 2. A padded square for the Android 12+ splash icon slot, which sizes and may
#    mask the drawable itself. Content sits in the central 70% so nothing clips.
SCALE = 0.70
CANVAS = 200.0
tx = round((CANVAS - VW * SCALE) / 2, 3)
ty = round((CANVAS - VH * SCALE) / 2, 3)
emit(f'{D}/tc_splash_icon.xml', 108, 108, CANVAS, CANVAS, SCALE, tx, ty)

# 3. The adaptive launcher icon foreground (API 26+). Deliberately the same
#    108dp canvas and the same 0.70 scale as the splash icon above: Android 12+
#    animates the launcher icon into the splash icon, so matching geometry makes
#    that handover seamless instead of a visible jump in the mark's size.
#    0.70 of the canvas is 56% of the layer, inside the 61% adaptive safe zone.
emit(f'{D}/ic_launcher_foreground.xml', 108, 108, CANVAS, CANVAS, SCALE, tx, ty)
