/*
Æ RayTracer Colour Version 4 ©Alan Evans 1998
---------------------------------------------
Combination of TRI2.e AND Compile1.e

New features Since colV3
------------------------
File Reader
250 Point buffers

New features Since colV2
------------------------
Auto Sphere,Light,Plane number allocation
Setup printout
Time printout inc pps
xc Bug fixed (Tighter intersectsphere() process)
Tighter closest() process

New features
------------
Matrix camera rotation
New ray direction calculator allowing different fields of view
Shade boundry ellimination for colour rendering
Special checkered planes process
*/

OPT PREPROCESS

MODULE 'other/battclock',
       'utility',
       'resources/battclock',
       'utility/date',
       'alanfile'

DEF xc,yc,zc,xd,yd,zd,xi,yi,zi,win,scr,xpix,ypix,mwin,
    /*Lights:*/  le[50]:ARRAY OF LONG,lx[50]:ARRAY OF LONG,
    ly[50]:ARRAY OF LONG,lz[50]:ARRAY OF LONG,lm[50]:ARRAY OF LONG,
    /*Planes:*/  pe[50]:ARRAY OF LONG,pa[50]:ARRAY OF LONG,
    pb[50]:ARRAY OF LONG,pc[50]:ARRAY OF LONG,pd[50]:ARRAY OF LONG,
    /*Spheres:*/ se[50]:ARRAY OF LONG,sx[50]:ARRAY OF LONG,
    sy[50]:ARRAY OF LONG,sz[50]:ARRAY OF LONG,sr[50]:ARRAY OF LONG,
    st[50]:ARRAY OF LONG,ildx,ildy,ildz,oix,oiy,oiz,ili,inum,itype,
    maxln=0,maxpn=0,maxsn=0,sdws,xangle,yangle,zangle,detail,rot,
    xrot=0,yrot=0,zrot=0,/*maxtn=0,*/drawmode,xfov,yfov,fieldofview,
    /*Triangles*/tpa[50]:ARRAY OF LONG,tpb[50]:ARRAY OF LONG,
    tpc[50]:ARRAY OF LONG,tpd[50]:ARRAY OF LONG,tpe[50]:ARRAY OF LONG,
    tpf[50]:ARRAY OF LONG,tpg[50]:ARRAY OF LONG,
    ta[50]:ARRAY OF LONG,tb[50]:ARRAY OF LONG,tc[50]:ARRAY OF LONG,
    td[50]:ARRAY OF LONG,maxtn=0,maxptn=0,
    pte[250]:ARRAY OF INT,ptx[250]:ARRAY OF LONG,pty[250]:ARRAY OF LONG,
    ptz[250]:ARRAY OF LONG,colmode,icol,randomise,rast,rastb=-1,winb=-1,
    tcol[50]:ARRAY OF INT,pcol[50]:ARRAY OF INT,scol[50]:ARRAY OF INT,
    file[31000]:STRING,rv[15]:ARRAY OF LONG,error=0

PROC main()
setup()
IF (error<>1)
scr:=OpenS(640,512,8,$8004,'Render 1 Scr')
win:=OpenW(0,0,640,512,$200,$100C,'Render Colour ©1998 Alan Evans',scr,$F,NIL,NIL)
->ScreenToBack(scr)
rast:=stdrast
setup2()
IF (mwin=1) THEN miniwindow()
printdata()
->ScreenToFront(scr)
render()
ScreenToFront(scr)
WaitIMessage(win)
IF (winb<>-1) THEN CloseW(winb)
CloseW(win)
CloseS(scr)
ENDIF
ENDPROC

PROC miniwindow()
IF (detail<>1) AND (drawmode<>1)
winb:=OpenW(-xpix/2+314,-ypix/2+248,xpix+12,ypix+16,$0,$2,'MiniWindow',scr,$F,NIL,NIL)
rastb:=stdrast
ELSE
mwin:=0
ENDIF
ENDPROC

PROC setup()
/*
OPTIONS
*/
detail:=10	->Detail: Lower the better
colmode:=1	->Colourmode: 1=Colours on, 0=Red & White
drawmode:=2	->Drawmode: 1=Normal ELSE Exploded
sdws:=0		->Shadows: 1=ON 0=OFF
randomise:=1	->Randomise: 1=ON TO Eliminate shade boundries
mwin:=0		->Miniwindow: 1=ON 0=OFF
fieldofview:=!12.0   ->Degrees (y only, x calculated atomatically)
xc:=!0.0
yc:=!0.0
zc:=!0.0
xangle:=!0.0
yangle:=!0.0
zangle:=!0.0
runreader() ->Read definition file
/*
END OF OPTIONS
*/
xpix:=600/detail
ypix:=480/detail
xfov:=!fieldofview*3.142*1.25/180.0
yfov:=!fieldofview*3.142/180.0
IF (!xangle=0.0) AND (!yangle=0.0) AND (!zangle=0.0)
rot:=0
ELSE
rot:=1
ENDIF
IF (!xangle<>0.0) THEN xrot:=1
IF (!yangle<>0.0) THEN yrot:=1
IF (!zangle<>0.0) THEN zrot:=1
/*
THIS IS WHERE THE
DEFINITIONS WOULD BE
*/
ENDPROC

PROC setup2()
DEF r,col
SetColour(scr,0,0,0,255)
SetColour(scr,4,0,0,0)
IF colmode=0
FOR col:=5 TO 125
r:=220*(col-5)/120+35
SetColour(scr,col,r,0,0)
ENDFOR
FOR col:=126 TO 255
r:=255*(col-126)/129
SetColour(scr,col,255,r,r)
ENDFOR
ELSE
colours()
ENDIF
ENDPROC

PROC render()
DEF xp,yp,col,ln,pn,type,time1,time2,dtime,fpt,
    cosx,sinx,cosy,siny,cosz,sinz,nxd,nyd,nzd
cosx:=!Fcos(!xangle);sinx:=!Fsin(!xangle)
cosy:=!Fcos(!yangle);siny:=!Fsin(!yangle) ->To save on recalculations
cosz:=!Fcos(!zangle);sinz:=!Fsin(!zangle)
->time1:=time()
FOR yp:=1 TO ypix
PrintF(' Lines Done: \d[3]/\d (\d%)\c',yp-1,ypix,yp-1*100/ypix,13)
FOR xp:=1 TO xpix
IF CtrlC() THEN JUMP out
->New ray angle calculations
xd:=!Ftan(!(xp-(xpix/2)!)*2.0*xfov/(xpix!))
yd:=!Ftan(!((ypix/2)-yp!)*2.0*yfov/(ypix!))
zd:=!1.0
->New Matrix Rotation Method
IF (rot=1)
IF (zrot=1)
nxd:=!xd*cosz+(!yd*sinz)
nyd:=!yd*cosz-(!xd*sinz)
xd:=!nxd
yd:=!nyd
ENDIF
IF (yrot=1)
nxd:=!xd*cosy+(!zd*siny)
nzd:=!zd*cosy-(!xd*siny)
xd:=!nxd
zd:=!nzd
ENDIF
IF (xrot=1)
nyd:=!yd*cosx+(!zd*sinx)
nzd:=!zd*cosx-(!yd*sinx)
yd:=!nyd
zd:=!nzd
ENDIF
ENDIF
->End of Rotations
->Start Colour
pn,type:=findclosest()
col:=4
  IF (pn<>-1)
   col:=0
     FOR ln:=1 TO maxln
       IF (sdws=1)
        IF (checklight(ln)<>-1) THEN col:=calcshade(pn,ln,type)+col
       ELSE
        col:=calcshade(pn,ln,type)+col
       ENDIF
     ENDFOR
->   IF (icol<1) THEN icol:=1
->   IF (icol>5) THEN icol:=5
   IF (colmode=1)
    IF (randomise=1) THEN col:=col+Rnd(5)-2
    col:=col*49/251
->    special(type)
/*
      IF (type=1)
      IF Even(!zi/10.0!) THEN col:=col+2   ->Stripy Texture
      IF Even(!xi/10.0!) THEN col:=col+2   ->Stripy Texture
      IF Even(!yi/10.0!) THEN col:=col+2   ->Stripy Texture
      ENDIF
*/
    IF (col>49) THEN col:=49
    IF (col<0) THEN col:=0
    col:=(icol-1)*50+col+5
   ELSE ->Monochrome
    col:=col+4
    IF (col>255) THEN col:=255
   ENDIF
  ENDIF
->Plot
IF (mwin=0)
 IF (drawmode=1) ->Drawmode 1=Normal ELSE=Exploded
  Plot(xp+20,yp+20,col)
 ELSE
  Box((xp-1)*detail+21,(yp-1)*detail+21,xp*detail+20,yp*detail+20,col)
 ENDIF
ELSE
 stdrast:=rastb
 Plot(xp+5,yp+11,col)
 stdrast:=rast
 Box((xp-1)*detail+21,(yp-1)*detail+21,xp*detail+20,yp*detail+20,col)
ENDIF
->Endplot
ENDFOR
ENDFOR
/*
time2:=time()
->time2:=10000
dtime:=time2-time1
WriteF('\d Pixles in ',xpix*ypix)
dms(dtime)
WriteF(' (\dsecs)\n',dtime)
WriteF('(\d Pixles per Second)\n',xpix*ypix/dtime)
fpt:=dtime*detail*detail
IF (detail<>1)
WriteF('Projected whole pic time ')
dms(fpt)
WriteF(' (\dsecs)\n',fpt)
ENDIF
*/
JUMP end
out:
WriteF('\nRender stopped: Ctrl-C Pressed\n')
end:
WriteF('\n')
ENDPROC

/*
PROC special(type)
IF (type=1)
IF Even(!yi/10.0!)
IF (Even(!xi/10.0!) AND Odd(!zi/10.0!)) OR
   (Odd(!xi/10.0!) AND Even(!zi/10.0!))
icol:=5
ENDIF
ELSE
IF (Even(!xi/10.0!) AND Even(!zi/10.0!)) OR
   (Odd(!xi/10.0!) AND Odd(!zi/10.0!))
icol:=5
ENDIF
ENDIF
ENDIF
ENDPROC
*/

PROC findclosest()
DEF sil,n,pn,type
->Select Closest Plane/Sphere/Triangle
pn:=-1
sil:=!9999999.0
FOR n:=1 TO maxpn
intersect(n)
IF (!ili<sil) AND (!ili>=0.0)
 pn:=n
 sil:=!ili
 type:=1
ENDIF
ENDFOR
->Spheres
FOR n:=1 TO maxsn
intersectsphere(n)
IF (!ili<sil) AND (!ili>=0.0)
 pn:=n
 sil:=!ili
 type:=2
ENDIF
ENDFOR
FOR n:=1 TO maxtn
  intersecttriangle(n)
  IF (!ili<sil) AND (!ili>=0.0)
  pn:=n
  sil:=!ili
  type:=3
  ENDIF
ENDFOR
inum:=pn
itype:=type
IF (pn<>-1)
SELECT type
CASE 1
intersect(pn)
icol:=pcol[pn]
CASE 2
intersectsphere(pn)
icol:=scol[pn]
CASE 3
intersecttriangle(pn)
icol:=tcol[pn]
ENDSELECT
ENDIF
ENDPROC pn,type

PROC calcshade(pn,ln,type)
DEF dx,dy,dz,s,a,b,c
dx:=!lx[ln]-xi
dy:=!ly[ln]-yi
dz:=!lz[ln]-zi
SELECT type
CASE 1
a:=!pa[pn]
b:=!pb[pn]
c:=!pc[pn]
CASE 2
a:=!xi-sx[pn]
b:=!yi-sy[pn]
c:=!zi-sz[pn]
CASE 3
a:=!ta[pn]
b:=!tb[pn]
c:=!tc[pn]
ENDSELECT
/*
d:=!Fsqrt(!dx*dx+(!dy*dy)+(!dz*dz)*1.7+170.0)
s:=!lm[ln]*130.0*(!a*dx+(!b*dy)+(!c*dz))/(!Fsqrt(!a*a+(!b*b)+(!c*c))*Fpow(!3.0,!d))
*/
s:=!lm[ln]*(!a*dx+(!b*dy)+(!c*dz))/(!Fsqrt(!a*a+(!b*b)+(!c*c))*
    (!dx*dx+(!dy*dy)+(!dz*dz)))
IF (type=2) AND (st[pn]=1)
IF (!(!-a*dx-(!b*dy)-(!c*dz))>0.0) THEN s:=!0.0
ENDIF
s:=Abs(!s!)
ENDPROC s

PROC intersect(pn,line=0)
DEF li,x,y,z,dx,dy,dz
IF (line=0)
x:=!xc;y:=!yc;z:=!zc
dx:=!xd;dy:=!yd;dz:=!zd
ELSE
x:=!oix;y:=!oiy;z:=!oiz
dx:=!ildx;dy:=!ildy;dz:=!ildz
ENDIF
li:=!(!pd[pn]-(!pa[pn]*x)-(!pb[pn]*y)-(!pc[pn]*z))/
     (!pa[pn]*dx+(!pb[pn]*dy)+(!pc[pn]*dz))
xi:=!li*dx+x
yi:=!li*dy+y
zi:=!li*dz+z
ili:=!li
->ip++
ENDPROC

PROC setlight(x,y,z,m,r=-1)
maxln++
le[maxln]:=1
lx[maxln]:=!x
ly[maxln]:=!y
lz[maxln]:=!z
lm[maxln]:=!m
IF (r<>-1) THEN definesphere(!x,!y,!z,!r,2)
ENDPROC

PROC defineplane(a,b,c,d,col=1)
maxpn++
pe[maxpn]:=1
pa[maxpn]:=!a
pb[maxpn]:=!b
pc[maxpn]:=!c
pd[maxpn]:=!d
pcol[maxpn]:=col
ENDPROC

PROC definesphere(x,y,z,r,type=1,col=1)
maxsn++
se[maxsn]:=1
sx[maxsn]:=!x
sy[maxsn]:=!y
sz[maxsn]:=!z
sr[maxsn]:=!r
st[maxsn]:=type
scol[maxsn]:=col
ENDPROC

PROC definepoint(x,y,z,pn=-1)
IF (pn=-1)
maxptn++
pn:=maxptn
ENDIF
pte[pn]:=1
ptx[pn]:=!x
pty[pn]:=!y
ptz[pn]:=!z
IF (pn>maxptn) THEN maxptn:=pn
->WriteF('\d\n',maxptn)
ENDPROC pn

PROC definequad(p1,p2,p3,p4,col=1)
definetriangle(p1,p2,p3,col)
definetriangle(p1,p4,p3,col)
ENDPROC

PROC definetriangle(p1,p2,p3,col=1)
DEF a,b,c,d,tn,n,pg,l,ps
IF (pte[p1]=1) AND (pte[p2]=1) AND (pte[p2]=1)
maxtn++
tn:=maxtn
tpa[tn]:=p1
tpb[tn]:=p2
tpc[tn]:=p3
tpg[tn]:=definepoint(!ptx[p1]+ptx[p2]+ptx[p3]/3.0,
   !pty[p1]+pty[p2]+pty[p3]/3.0,!ptz[p1]+ptz[p2]+ptz[p3]/3.0)
pg:=tpg[tn]
FOR n:=1 TO 3
IF (n<>1)
ps:=p1
p1:=p2
p2:=p3
p3:=ps
ENDIF
a:=!ptx[p2]-ptx[p1]
b:=!pty[p2]-pty[p1]
c:=!ptz[p2]-ptz[p1]
d:=!ptx[pg]*a+(!pty[pg]*b)+(!ptz[pg]*c)
l:=!(!d-(!a*ptx[p1])-(!b*pty[p1])-(!c*ptz[p1]))/(!a*a+(!b*b)+(!c*c))
SELECT n
CASE 1
tpd[tn]:=definepoint(!2.0*(!ptx[p1]+(!ptx[p2]-ptx[p1]*l))-ptx[pg],
!2.0*(!pty[p1]+(!pty[p2]-pty[p1]*l))-pty[pg],
!2.0*(!ptz[p1]+(!ptz[p2]-ptz[p1]*l))-ptz[pg])
CASE 2
tpe[tn]:=definepoint(!2.0*(!ptx[p1]+(!ptx[p2]-ptx[p1]*l))-ptx[pg],
!2.0*(!pty[p1]+(!pty[p2]-pty[p1]*l))-pty[pg],
!2.0*(!ptz[p1]+(!ptz[p2]-ptz[p1]*l))-ptz[pg])
CASE 3
tpf[tn]:=definepoint(!2.0*(!ptx[p1]+(!ptx[p2]-ptx[p1]*l))-ptx[pg],
!2.0*(!pty[p1]+(!pty[p2]-pty[p1]*l))-pty[pg],
!2.0*(!ptz[p1]+(!ptz[p2]-ptz[p1]*l))-ptz[pg])
ENDSELECT
ENDFOR
/*
dispcoords(tpd[tn])
dispcoords(tpe[tn])
dispcoords(tpf[tn])
dispcoords(tpg[tn])
*/
ta[maxtn]:=!(!ptz[p1]-ptz[p2])*(!pty[p3]-pty[p2])-
        (!(!pty[p1]-pty[p2])*(!ptz[p3]-ptz[p2]))
tb[maxtn]:=!(!ptx[p1]-ptx[p2])*(!ptz[p3]-ptz[p2])-
        (!(!ptz[p1]-ptz[p2])*(!ptx[p3]-ptx[p2]))
tc[maxtn]:=!(!pty[p1]-pty[p2])*(!ptx[p3]-ptx[p2])-
        (!(!ptx[p1]-ptx[p2])*(!pty[p3]-pty[p2]))
td[maxtn]:=!ptx[p1]*ta[tn]+(!pty[p1]*tb[tn])+(!ptz[p1]*tc[tn])
IF (!ta[maxtn]=0.0) AND (!tb[maxtn]=0.0) AND (!tc[maxtn]=0.0)
maxtn--
ENDIF
/*
WriteF('Triangle a=\s, ',RealF(str,ta[tn],3))
WriteF('b=\s, ',RealF(str,tb[tn],3))
WriteF('c=\s, ',RealF(str,tc[tn],3))
WriteF('d=\s\n',RealF(str,td[tn],3))
*/
ENDIF
tcol[tn]:=col
ENDPROC

PROC intersectsphere(sn,line=0)
DEF a,b,c,li1,li2,i=1,dx,dy,dz,x,y,z,dis
IF (line=0)
x:=!xc;y:=!yc;z:=!zc
dx:=!xd;dy:=!yd;dz:=!zd
ELSE
x:=!oix;y:=!oiy;z:=!oiz
dx:=!ildx;dy:=!ildy;dz:=!ildz
ENDIF
a:=!dx*dx+(!dy*dy)+(!dz*dz)
b:=!2.0*(!(!(!x-sx[sn])*dx)+(!(!y-sy[sn])*dy)+(!(!z-sz[sn])*dz))
c:=!(!x-sx[sn])*(!x-sx[sn])+
    (!(!y-sy[sn])*(!y-sy[sn]))+
    (!(!z-sz[sn])*(!z-sz[sn]))-
    (!sr[sn]*sr[sn])
dis:=!b*b-(!4.0*a*c)
IF (!dis>=0.0)
li1:=!(!-Fsqrt(!dis)-b)/(!2.0*a)
li2:=!(!Fsqrt(!dis)-b)/(!2.0*a)
IF (!li1<li2) THEN ili:=!li1 ELSE ili:=!li2
xi:=!ili*dx+x
yi:=!ili*dy+y
zi:=!ili*dz+z
ELSE
i:=-1
ili:=!-1.0
ENDIF
->is++
ENDPROC i

PROC checklight(ln)
DEF n,r=-1
oix:=!xi
oiy:=!yi
oiz:=!zi
ildx:=!lx[ln]-oix
ildy:=!ly[ln]-oiy
ildz:=!lz[ln]-oiz
FOR n:=1 TO maxpn
 IF (pe[n]=1) AND ((inum<>n) OR (itype<>1))
  intersect(n,1)
  IF (!ili>0.0) AND (!ili<1.0) THEN JUMP unvalid
 ENDIF
ENDFOR
FOR n:=1 TO maxsn
 IF (se[n]=1) AND (st[n]=1) AND ((inum<>n) OR (itype<>2))
  intersectsphere(n,1)
  IF (!ili>0.0) AND (!ili<1.0) THEN JUMP unvalid
 ENDIF
ENDFOR
r:=1
unvalid:
xi:=!oix
yi:=!oiy
zi:=!oiz
->cl++
ENDPROC r

PROC intersecttriangle(tn,line=0)
DEF dd,de,df,dg,ix,iy,iz,x,y,z,dx,dy,dz,li
ix:=!xi
iy:=!yi
iz:=!zi
IF (line=0)
x:=!xc;y:=!yc;z:=!zc
dx:=!xd;dy:=!yd;dz:=!zd
ELSE
x:=!oix;y:=!oiy;z:=!oiz
dx:=!ildx;dy:=!ildy;dz:=!ildz
ENDIF
li:=!(!td[tn]-(!ta[tn]*x)-(!tb[tn]*y)-(!tc[tn]*z))/
     (!ta[tn]*dx+(!tb[tn]*dy)+(!tc[tn]*dz))
xi:=!li*dx+x
yi:=!li*dy+y
zi:=!li*dz+z
ili:=!li
ix:=!xi
iy:=!yi
iz:=!zi
dd:=!(!ptx[tpd[tn]]-ix)*(!ptx[tpd[tn]]-ix)+
(!(!pty[tpd[tn]]-iy)*(!pty[tpd[tn]]-iy))+
(!(!ptz[tpd[tn]]-iz)*(!ptz[tpd[tn]]-iz))
de:=!(!ptx[tpe[tn]]-ix)*(!ptx[tpe[tn]]-ix)+
(!(!pty[tpe[tn]]-iy)*(!pty[tpe[tn]]-iy))+
(!(!ptz[tpe[tn]]-iz)*(!ptz[tpe[tn]]-iz))
df:=!(!ptx[tpf[tn]]-ix)*(!ptx[tpf[tn]]-ix)+
(!(!pty[tpf[tn]]-iy)*(!pty[tpf[tn]]-iy))+
(!(!ptz[tpf[tn]]-iz)*(!ptz[tpf[tn]]-iz))
dg:=!(!ptx[tpg[tn]]-ix)*(!ptx[tpg[tn]]-ix)+
(!(!pty[tpg[tn]]-iy)*(!pty[tpg[tn]]-iy))+
(!(!ptz[tpg[tn]]-iz)*(!ptz[tpg[tn]]-iz))-0.1
IF (!dd>dg) AND (!de>dg) AND (!df>dg)
ELSE
ili:=!-1.0
ENDIF
ENDPROC

PROC colours()
DEF a,b,c,g,r,s,cn
FOR a:=0 TO 49
->First halve (Black to colour)
s:=200*a/49+55
SetColour(scr,a+5,s,s,s)
ENDFOR
FOR c:=2 TO 5
FOR a:=0 TO 24
s:=200*a/24+55
r:=s
g:=s
b:=s
SELECT c
CASE 1
cn:=a+5
CASE 2
cn:=a+55;g:=0;b:=0
CASE 3
cn:=a+105;r:=0;g:=0
CASE 4
cn:=a+155;r:=0;b:=0
CASE 5
cn:=a+205;b:=0
ENDSELECT
SetColour(scr,cn,r,g,b)
->Second halve (Colour to white)
s:=255*a/24
r:=s
g:=s
b:=s
SELECT c
CASE 1
cn:=a+30
CASE 2
cn:=a+80;r:=255
CASE 3
cn:=a+130;b:=255
CASE 4
cn:=a+180;g:=255
CASE 5
cn:=a+230;r:=255;g:=255
ENDSELECT
SetColour(scr,cn,r,g,b)
ENDFOR
ENDFOR
ENDPROC

->DISPLAY PROCESSES

PROC time()
DEF seconds
utilitybase:=OpenLibrary('utility.library', 33)
battclockbase:=OpenResource(BATTCLOCKNAME)
seconds:=readBattClock()
->WriteF('\d\n',seconds)
IF utilitybase THEN CloseLibrary(utilitybase)
ENDPROC seconds

PROC printdata()
DEF a[50]:STRING,b[50]:STRING,c[50]:STRING
WriteF('\nPicture and Engine Setup Data:\n')
WriteF('\d×\d (Detail \d) ',xpix,ypix,detail)
IF (colmode=1) THEN WriteF('Colour,\n') ELSE WriteF('Monochrome,\n')
IF (sdws=1) THEN WriteF('Shadows active,\n') ELSE WriteF('No Shadows,\n')
WriteF('Shade boundries elimination ')
IF (randomise=1) THEN WriteF('on,\n') ELSE WriteF('off,\n')
WriteF('Miniwindow ')
IF (mwin=1) THEN WriteF('on,\n') ELSE WriteF('off,\n')
WriteF('Field of view: \s° × \s° (to 2dp)\n',RealF(a,!fieldofview*1.25,2),
                    RealF(b,!fieldofview,2))
WriteF('\d Lights, \d Planes, \d Spheres\n',maxln,maxpn,maxsn)
WriteF('Camera is at (\s,\s,\s)\n',RealF(a,xc,2),RealF(b,yc,2),RealF(c,zc,2))
WriteF('   And has angles of:\n')
WriteF('    xangle: \s rads\n',RealF(a,xangle,3))
WriteF('    yangle: \s rads\n',RealF(a,yangle,3))
WriteF('    zangle: \s rads\n',RealF(a,zangle,3))
WriteF('\nRendering Data:\n')
ENDPROC

PROC dms(secs)
WriteF('\d:\d:\d',
secs/3600,
secs/60-((secs/3600)*60),
secs-((secs/60-((secs/3600)*60))*60)-((secs/3600)*3600) )
ENDPROC

/*
PROC dispcoords(ptn)
DEF strx[20]:STRING,stry[20]:STRING,strz[20]:STRING
WriteF('point[\d]=(\s,\s,\s)\n',ptn,RealF(strx,ptx[ptn],2),RealF(stry,pty[ptn],2),
RealF(strz,ptz[ptn],2))
ENDPROC
*/

->FILE READER

PROC runreader()
IF (StrLen(arg)>1) AND (FileLength(arg)>10)
StrCopy(file,readfile(arg,1))
reader()
ELSE
WriteF('File Error, Check name\nUsage: Render <filename>\n')
error:=1
ENDIF
ENDPROC

PROC reader()
DEF n,buf[100]:STRING
FOR n:=0 TO StrLen(file)
MidStr(buf,file,n,3)
UpperStr(buf)
IF StrCmp(buf,'CAM') THEN camdef(n+3)
IF StrCmp(buf,'LGT') THEN lightdef(n+3)
IF StrCmp(buf,'PLN') THEN planedef(n+3)
IF StrCmp(buf,'SPH') THEN spheredef(n+3)
IF StrCmp(buf,'PNT') THEN pointdef(n+3)
IF StrCmp(buf,'TRI') THEN triangdef(n+3)
IF StrCmp(buf,'SQR') THEN quaddef(n+3)
IF StrCmp(buf,'OPT') THEN optset(n+3)
ENDFOR
ENDPROC

PROC camdef(n)
->WriteF('Camera def\n')
get(6,n)
xc:=!rv[1]
yc:=!rv[2]
zc:=!rv[3]
IF (rv[4]<>-1) THEN xangle:=!rv[4]
IF (rv[5]<>-1) THEN yangle:=!rv[5]
IF (rv[6]<>-1) THEN zangle:=!rv[6]
ENDPROC

PROC lightdef(n)
->WriteF('Light def\n')
get(5,n)
setlight(rv[1],rv[2],rv[3],rv[4],rv[5]) ->(x,y,z,mag,r=-1)
ENDPROC

PROC planedef(n)
->WriteF('Plane def\n')
get(5,n)
IF (rv[5]<>-1)
defineplane(rv[1],rv[2],rv[3],rv[4],!rv[5]!) ->(a,b,c,d,col)
ELSE
defineplane(rv[1],rv[2],rv[3],rv[4]) ->(a,b,c,d)
ENDIF
ENDPROC

PROC spheredef(n)
->WriteF('Sphere def\n')
get(6,n)
IF (rv[5]=-1) THEN rv[5]:=!1.0
IF (rv[6]<>-1)
definesphere(rv[1],rv[2],rv[3],rv[4],!rv[6]!,!rv[5]!) ->(x,y,z,r,type,col)
ELSE
definesphere(rv[1],rv[2],rv[3],rv[4],1,!rv[5]!) ->(x,y,z,r,1,col)
ENDIF
->WriteF('SPH(\d,\d,\d,\d)\n',!rv[1]!,!rv[2]!,!rv[3]!,!rv[4]!)
ENDPROC

PROC pointdef(n)
->WriteF('Point def\n')
get(4,n)
definepoint(rv[2],rv[3],rv[4],!rv[1]!) ->(x,y,z,pnt)
ENDPROC

PROC triangdef(n)
->WriteF('Triangle def\n')
get(4,n)
IF (rv[4]<>-1)
definetriangle(!rv[1]!,!rv[2]!,!rv[3]!,!rv[4]!) ->(pnt,pnt,pnt,col)
ELSE
definetriangle(!rv[1]!,!rv[2]!,!rv[3]!) ->(pnt,pnt,pnt)
ENDIF
ENDPROC

PROC quaddef(n)
->WriteF('Quad def\n')
get(5,n)
IF (rv[5]<>-1)
definequad(!rv[1]!,!rv[2]!,!rv[3]!,!rv[4]!,!rv[5]!) ->(pnt,pnt,pnt,pnt,col)
ELSE
definequad(!rv[1]!,!rv[2]!,!rv[3]!,!rv[4]!)
ENDIF
ENDPROC

PROC optset(n)
DEF opt
get(2,n)
opt:=!rv[1]!
SELECT opt
CASE 1 ->Detail Set
detail:=Bounds(!rv[2]!,1,30)
CASE 2 ->Shadows Set
sdws:=Bounds(!rv[2]!,0,1)
CASE 3 ->Boundry ellimination
randomise:=Bounds(!rv[2]!,0,1)
CASE 4 ->Set y field of view in degrees
fieldofview:=!rv[2]
ENDSELECT
ENDPROC

PROC get(x,n)
DEF end,/*buf[250]:STRING,*/a,cm,cm2,om,vbuf[50]:STRING
end:=InStr(file,')',n+1)
->MidStr(buf,file,n,end-n+1)
->WriteF('-\s-\n',buf)
om:=n
FOR a:=1 TO x
cm:=InStr(file,')',om+1)
cm2:=InStr(file,',',om+1)
IF (cm=-1) AND (cm2=-1)
StrCopy(vbuf,' err1 ')
ELSE
IF (cm=-1) THEN cm:=35000
IF (cm2<cm) AND (cm2<>-1) THEN cm:=cm2
IF (cm>end)
StrCopy(vbuf,' err2 ')
ELSE
MidStr(vbuf,file,om+1,cm-om-1)
ENDIF
ENDIF
->WriteF('-\s-\n',vbuf)
IF StrCmp(vbuf,' err1 ') OR
   StrCmp(vbuf,' err2 ')
rv[a]:=-1
ELSE
rv[a]:=RealVal(vbuf)
ENDIF
om:=cm
ENDFOR
ENDPROC
