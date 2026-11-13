#!/usr/bin/env python3
"""Render opaque editorial artwork with the shipping Day in Ink icon and theme."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/store-assets/day-in-ink/creative'
OUT.mkdir(parents=True, exist_ok=True)
PAPER, INK, SECONDARY, RULE = '#F4F0E7', '#202F43', '#59616D', '#D8D6D0'
ICON = ROOT / 'apps/DayInInk/Assets.xcassets/AppIcon.appiconset/icon-1024.png'

def font(size, handwritten=False):
    return ImageFont.truetype('/System/Library/Fonts/' + ('Noteworthy.ttc' if handwritten else 'Avenir Next.ttc'), size)

def tracked(draw, xy, text, size, spacing, fill):
    x, y = xy
    face = font(size)
    for char in text:
        draw.text((x, y), char, font=face, fill=fill)
        x += draw.textlength(char, font=face) + spacing

def artwork(size, safe, name):
    w, h = size
    canvas = Image.new('RGB', size, PAPER)
    draw = ImageDraw.Draw(canvas)
    # Full-bleed notebook rules stay intentionally quiet beneath the central lockup.
    for y in range(108, h, 102):
        draw.line((0, y, w, y), fill='#E5E0D5', width=2)
    draw.line((610, 0, 610, h), fill='#D5B9A6', width=3)
    # Oversized pen-stroke arcs are decorative, not a fabricated app interface.
    draw.arc((-430, h-1030, 820, h+230), 205, 338, fill='#C4CCC3', width=18)
    draw.arc((w-680, -470, w+470, 680), 35, 175, fill='#D4C5B0', width=18)
    x, y, sw, sh = safe
    if name == 'header':
        icon_size = 270
        ix, iy = x+60, y+164
        tx, ty = x+396, y+110
        title_size, subtitle_size = 126, 43
    else:
        icon_size = 374
        ix, iy = x+104, y+279
        tx, ty = x+590, y+218
        title_size, subtitle_size = 156, 48
    # Hide ruled lines only under the editorial text region for clean legibility.
    draw.rounded_rectangle((x, y+48, x+sw, y+sh-48), radius=32, fill=PAPER)
    icon = Image.open(ICON).convert('RGB').resize((icon_size, icon_size), Image.Resampling.LANCZOS)
    mask = Image.new('L', icon.size)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,icon_size,icon_size), radius=int(icon_size*.22), fill=255)
    canvas.paste(icon, (ix,iy), mask)
    tracked(draw, (tx, ty), 'SMALL STEPS. LASTING MARKS.', 27 if name == 'header' else 32, 4, SECONDARY)
    title_font = font(title_size, True)
    title_xy = (tx, ty+58)
    draw.text(title_xy, 'Day in Ink', font=title_font, fill=INK)
    title_bottom = draw.textbbox(title_xy, 'Day in Ink', font=title_font)[3]
    subtitle_xy = (tx+3, title_bottom+30)
    subtitle_font = font(subtitle_size)
    draw.text(subtitle_xy, 'Leave a mark today.', font=subtitle_font, fill=SECONDARY, anchor='lt')
    subtitle_bottom = draw.textbbox(subtitle_xy, 'Leave a mark today.', font=subtitle_font, anchor='lt')[3]
    length = 815 if name == 'header' else 1120
    line_y = subtitle_bottom+32
    draw.line((tx+3, line_y, tx+length, line_y), fill='#C9C9BC', width=3)
    tracked(draw, (tx+3, line_y+26), 'HABITS  /  CHECK-INS  /  TRENDS', 23 if name == 'header' else 28, 2.1, INK)
    dest = OUT / (name + '.png')
    canvas.save(dest, optimize=True)
    return dict(path=str(dest.relative_to(ROOT)), dimensions=list(size), colorMode=canvas.mode, safeRectangle=dict(x=x,y=y,width=sw,height=sh), sourceIcon=str(ICON.relative_to(ROOT)), sourceTheme='apps/DayInInk/App/Theme.swift', containsScreenshots=False, purpose='App Store editorial creative, not an app screenshot')

assets = [artwork((3840,1646),(1097,493,1646,661),'header'), artwork((3840,2560),(836,765,2168,1030),'search-results')]
(OUT/'creative-metadata.json').write_text(json.dumps(assets,indent=2)+'\n')
for asset in assets:
    print(asset['path'], asset['dimensions'], asset['colorMode'])
