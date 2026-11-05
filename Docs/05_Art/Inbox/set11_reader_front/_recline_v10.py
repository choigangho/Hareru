import sys
from PIL import Image
S=sys.argv[1]
im=Image.open(f'{S}/front_v10a.png').convert('RGB'); out=im.copy()
X0,X1,Y1,K=100,238,122,6          # panel columns, bottom row of the tilt, top inset (art px)
for y in range(0,Y1):
    i=round(K*(Y1-y)/Y1)
    if i==0: continue
    seg=im.crop((X0,y,X1,y+1)).resize((X1-X0-2*i,1),Image.NEAREST)
    out.paste(seg,(X0+i,y))
    for j in range(i):
        out.putpixel((X0+j,y),im.getpixel((X0-1-j,y)))       # background shows where the top leans back
        out.putpixel((X1-1-j,y),im.getpixel((X1+j,y)))
out.save(f'{S}/front_v10.png'); out.resize((1280,720),Image.NEAREST).save(f'{S}/front_v10_x4.png')
