from PIL import Image, ImageDraw
import numpy as np, os
from scipy import ndimage as ndi
src=Image.open('/downloads/image-563d8dfb.jpg').convert('RGB'); a=np.array(src).astype(float); lum=a.mean(axis=2)
b=ndi.binary_opening(lum>60,iterations=2); lab,n=ndi.label(b); k=np.argmax(ndi.sum(b,lab,range(1,n+1)))+1
keep=ndi.binary_dilation(lab==k,iterations=14)
ys,xs=np.where(lab==k); x0,y0,x1,y1=xs.min()-10,ys.min()-10,xs.max()+10,ys.max()+10
t=np.clip((lum-25)/90,0,1); al=t*t*(3-2*t)*keep
rgba=np.dstack([a,al*255]).astype(np.uint8)[y0:y1,x0:x1]
glyph=Image.fromarray(rgba,'RGBA')
def fg(size,tw=244):
    can=Image.new('RGBA',(432*4,432*4),(0,0,0,0)); w=tw*4; h=round(glyph.height*w/glyph.width)
    g=glyph.resize((w,h),Image.LANCZOS); can.paste(g,((432*4-w)//2,(432*4-h)//2),g)
    return can.resize((size,size),Image.LANCZOS)
def mono(size):
    f=fg(432); m=Image.new('RGBA',(432,432),(255,255,255,0)); m.putalpha(f.split()[3]); return m.resize((size,size),Image.LANCZOS)
BG=(7,8,13,255); res='app/src/main/res'
for d,(leg,f) in {'mdpi':(48,108),'hdpi':(72,162),'xhdpi':(96,216),'xxhdpi':(144,324),'xxxhdpi':(192,432)}.items():
    p=f'{res}/mipmap-{d}/'
    fg(f).save(p+'ic_launcher_foreground.webp',lossless=True); mono(f).save(p+'ic_launcher_monochrome.webp',lossless=True)
    sq=Image.alpha_composite(Image.new('RGBA',(432,432),BG),fg(432)); c=36
    L=sq.crop((c,c,432-c,432-c)).resize((leg,leg),Image.LANCZOS)
    L.convert('RGB').save(p+'ic_launcher.webp',lossless=True)
    m=Image.new('L',(leg*4,leg*4),0); ImageDraw.Draw(m).ellipse((0,0,leg*4-1,leg*4-1),fill=255); r=L.copy(); r.putalpha(m.resize((leg,leg),Image.LANCZOS)); r.save(p+'ic_launcher_round.webp',lossless=True)
Image.alpha_composite(Image.new('RGBA',(432,432),BG),fg(432)).resize((512,512),Image.LANCZOS).convert('RGB').save('app/src/main/ic_launcher-playstore.png')
fg(1024,244).save('/tmp/fg1024.png')
