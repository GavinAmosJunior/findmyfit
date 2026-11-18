# Draws the FindMyFit app icon. Run from the repo root: python tool/make_icon.py
# then: dart run flutter_launcher_icons
from PIL import Image, ImageDraw, ImageFont, ImageFilter
S=1024
fill=ImageFont.truetype('assets/fonts/Phosphor-Fill.ttf', 10)
def glyph(code,size,color):
    f=ImageFont.truetype('assets/fonts/Phosphor-Fill.ttf', size)
    ch=chr(code)
    l,t,r,b=f.getbbox(ch)
    im=Image.new('RGBA',(r-l,b-t),(0,0,0,0))
    ImageDraw.Draw(im).text((-l,-t),ch,font=f,fill=color)
    return im
def gradient(size):
    top=(56,140,255); bot=(0,72,190)
    g=Image.new('RGB',(1,size))
    for y in range(size):
        k=y/(size-1); g.putpixel((0,y),tuple(int(top[i]+(bot[i]-top[i])*k) for i in range(3)))
    return g.resize((size,size))
def art(canvas,scale):
    # hanger, then a check badge overlapping its lower right
    c=canvas.size[0]
    h=glyph(0xe7fe,int(620*scale),(255,255,255,255))
    d=int(260*scale)
    gw=h.width+int(d*0.25); gh=h.height+int(d*0.55)
    hx=(c-gw)//2; hy=(c-gh)//2
    # soft shadow for depth
    sh=Image.new('RGBA',canvas.size,(0,0,0,0)); sh.paste((0,30,90,90),(hx,hy+int(14*scale)),h)
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(18*scale)))
    canvas.alpha_composite(h,(hx,hy))
    bx=hx+h.width-int(d*0.75); by=hy+h.height-int(d*0.45)
    ring=int(22*scale)
    badge=Image.new('RGBA',(d+2*ring,d+2*ring),(0,0,0,0))
    bd=ImageDraw.Draw(badge)
    bd.ellipse((0,0,d+2*ring-1,d+2*ring-1),fill=canvas.getpixel((min(bx+d//2,c-1),min(by+d//2,c-1))) if canvas.getpixel((0,0))[3] else (0,0,0,0))  # cut-out ring in the blue
    bd.ellipse((ring,ring,ring+d,ring+d),fill=(52,211,153,255))
    chk=glyph(0xe182,int(d*0.62),(255,255,255,255)) if False else None
    f=ImageFont.truetype('assets/fonts/Phosphor-Bold.ttf', int(d*0.62))
    l,t,r,b=f.getbbox(chr(0xe182))
    bd.text((ring+(d-(r-l))//2-l, ring+(d-(b-t))//2-t),chr(0xe182),font=f,fill=(255,255,255,255))
    if canvas.getpixel((0,0))[3]==0:
        # transparent foreground: cut a real gap around the badge
        m=Image.new('L',badge.size,0); ImageDraw.Draw(m).ellipse((0,0,badge.width-1,badge.height-1),fill=255)
        canvas.paste((0,0,0,0),(bx-ring,by-ring),m)
    canvas.alpha_composite(badge,(bx-ring,by-ring))
# full icon (iOS + legacy Android)
full=gradient(S).convert('RGBA'); art(full,1.0)
full.convert('RGB').save('assets/icon/app_icon.png')
# adaptive: gradient background + transparent foreground in the safe zone
gradient(S).save('assets/icon/app_icon_background.png')
fg=Image.new('RGBA',(S,S),(0,0,0,0)); art(fg,0.76)
fg.save('assets/icon/app_icon_foreground.png')
