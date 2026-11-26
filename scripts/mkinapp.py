from PIL import Image, ImageFilter
import numpy as np
from scipy import ndimage as ndi
src=Image.open('/downloads/image-563d8dfb.jpg').convert('RGB'); a=np.array(src).astype(float); lum=a.mean(axis=2)
# tile mask
m=ndi.binary_closing(lum>10,iterations=6); m=ndi.binary_fill_holes(m); lab,n=ndi.label(m); k=np.argmax(ndi.sum(m,lab,range(1,n+1)))+1
tm=ndi.binary_erosion(lab==k,iterations=3)
ys,xs=np.where(tm); x0,y0,x1,y1=xs.min(),ys.min(),xs.max()+1,ys.max()+1; print('tile',x0,y0,x1,y1)
al=Image.fromarray((tm*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
rgba=src.convert('RGBA'); rgba.putalpha(al)
t=rgba.crop((x0,y0,x1,y1)); s=max(t.size); sq=Image.new('RGBA',(s,s),(0,0,0,0)); sq.paste(t,((s-t.width)//2,(s-t.height)//2))
sq.resize((1024,1024),Image.LANCZOS).save('shared/ui/core/src/main/res/drawable-nodpi/ivy_wallet_logo.png',optimize=True)
# notification silhouette
b=ndi.binary_opening(lum>60,iterations=2); lab,n=ndi.label(b); k=np.argmax(ndi.sum(b,lab,range(1,n+1)))+1
sil=ndi.binary_closing(lab==k,iterations=8); sil=ndi.binary_fill_holes(sil)
ys,xs=np.where(sil); g=Image.fromarray((sil*255).astype(np.uint8)).crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1))
for name in ['ic_notification','ic_notification_m']:
    S=4; W=22*S*4  # 352 wide inside 384 canvas (24dp@16x)
    c=Image.new('L',(384,384),0); w=352; h=round(g.height*w/g.width); gg=g.resize((w,h),Image.LANCZOS)
    c.paste(gg,((384-w)//2,(384-h)//2))
    c=c.resize((192,192),Image.LANCZOS)
    o=Image.new('RGBA',(192,192),(255,255,255,0)); o.putalpha(c)
    o.save(f'shared/ui/core/src/main/res/drawable-nodpi/{name}.png',optimize=True)
