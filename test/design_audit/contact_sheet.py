#!/usr/bin/env python3
"""PNG 폴더를 4장씩 묶은 확인용 시트로 만든다.  사용: contact_sheet.py <png폴더> <출력폴더> [접두사]"""
import sys, glob, os
from PIL import Image, ImageDraw
src, dst = sys.argv[1], sys.argv[2]
prefix = sys.argv[3] if len(sys.argv) > 3 else ''
os.makedirs(dst, exist_ok=True)
files = sorted(f for f in glob.glob(os.path.join(src, prefix + '*.png')))
W, H, PER = 390, 844, 4
for n in range(0, len(files), PER):
    chunk = files[n:n+PER]
    sheet = Image.new('RGB', (W*PER + 10*(PER+1), H + 40), (229, 231, 235))
    d = ImageDraw.Draw(sheet)
    for i, f in enumerate(chunk):
        im = Image.open(f).convert('RGB').resize((W, H))
        x = 10 + i*(W+10)
        sheet.paste(im, (x, 30))
        d.text((x, 8), os.path.basename(f)[:-4], fill=(17, 24, 39))
    sheet.save(os.path.join(dst, f'sheet-{prefix}{n//PER+1:02d}.png'))
print(len(files), 'files')
