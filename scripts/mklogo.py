from PIL import Image, ImageDraw
src=Image.open('/downloads/image-563d8dfb.jpg').convert('RGB')
x0,y0,x1,y1=93,93,1161,1158   # tile bounds (1 px inset)
S=4; r=268
side=max(x1-x0,y1-y0)
t=src.crop((x0,y0,x1,y1)); sq=Image.new('RGB',(side,side),(0,0,0)); sq.paste(t,((side-t.width)//2,(side-t.height)//2))
big=Image.new('L',(side*S,side*S),0)
ox=(side-t.width)//2*S; oy=(side-t.height)//2*S
ImageDraw.Draw(big).rounded_rectangle((ox,oy,ox+t.width*S-1,oy+t.height*S-1),radius=r*S,fill=255)
mask=big.resize((side,side),Image.LANCZOS)
out=sq.convert('RGBA'); out.putalpha(mask)
out.resize((1024,1024),Image.LANCZOS).save('shared/ui/core/src/main/res/drawable-nodpi/ivy_wallet_logo.png',optimize=True)
