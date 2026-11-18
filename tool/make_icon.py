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
    top=(43,96,190); bot=(31,79,160)  # sign blue, a touch lighter at the top
    g=Image.new('RGB',(1,size))
    for y in range(size):
        k=y/(size-1); g.putpixel((0,y),tuple(int(top[i]+(bot[i]-top[i])*k) for i in range(3)))
    return g.resize((size,size))
def art(canvas,scale,lift=0):
    # hanger, then a check badge overlapping its lower right
    c=canvas.size[0]
    h=glyph(0xe7fe,int(620*scale),(255,255,255,255))
    d=int(260*scale)
    gw=h.width+int(d*0.25); gh=h.height+int(d*0.55)
    hx=(c-gw)//2; hy=(c-gh)//2-lift
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
THREAD=(226,69,60,255)
INK=(22,24,27,255); CHALK=(244,242,236,255); MUSTARD=(233,178,58,255)
def floor(img, band, tile):
    # laundromat floor along the bottom: mustard trim, then checkerboard
    d=ImageDraw.Draw(img); c=img.size[0]; top=c-band
    d.rectangle((0,top-int(tile*0.35),c,top),fill=MUSTARD)
    for row in range(0, band//tile+1):
        for col in range(0, c//tile+1):
            d.rectangle((col*tile,top+row*tile,col*tile+tile-1,top+row*tile+tile-1),fill=INK if (row+col)%2==0 else CHALK)
def stitch(img, inset, circle=False, dash=34, gap=22, width=10):
    import math
    d=ImageDraw.Draw(img)
    c=img.size[0]
    if circle:
        r=c/2-inset; n=int(2*math.pi*r/(dash+gap))
        for k in range(n):
            a0=2*math.pi*k/n; a1=a0+2*math.pi*dash/(dash+gap)/n
            d.arc((c/2-r,c/2-r,c/2+r,c/2+r), math.degrees(a0), math.degrees(a1), fill=THREAD, width=width)
        return
    # rounded square seam, drawn as dashes along its outline
    rad=170; L=inset; R=c-inset
    pts=[]
    def seg(x0,y0,x1,y1):
        length=math.hypot(x1-x0,y1-y0); s=0
        while s<length:
            e=min(s+dash,length)
            pts.append(((x0+(x1-x0)*s/length,y0+(y1-y0)*s/length),(x0+(x1-x0)*e/length,y0+(y1-y0)*e/length)))
            s+=dash+gap
    seg(L+rad,L,R-rad,L); seg(R,L+rad,R,R-rad); seg(R-rad,R,L+rad,R); seg(L,R-rad,L,L+rad)
    for a,b in pts: d.line([a,b],fill=THREAD,width=width)
    for cx,cy,start in ((L+rad,L+rad,180),(R-rad,L+rad,270),(R-rad,R-rad,0),(L+rad,R-rad,90)):
        for k in range(3):
            a0=start+k*30+4; d.arc((cx-rad,cy-rad,cx+rad,cy+rad),a0,a0+18,fill=THREAD,width=width)

# full icon (iOS + legacy Android)
full=gradient(S).convert('RGBA'); floor(full,190,64); art(full,0.8,lift=95)
full.convert('RGB').save('assets/icon/app_icon.png')
# adaptive: gradient background + transparent foreground in the safe zone
bg=gradient(S).convert('RGBA'); floor(bg,300,56); bg.convert('RGB').save('assets/icon/app_icon_background.png')
fg=Image.new('RGBA',(S,S),(0,0,0,0)); art(fg,0.66,lift=80)
fg.save('assets/icon/app_icon_foreground.png')
