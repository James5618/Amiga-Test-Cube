;Rotate 3D Wireframe Objects
;
;assembler : ASMTwo

		SECTION Arn,CODE_C


DEBUGDISPLAYTIME=0	;Display Debug
BLITTER=1		;Tracing using Blitter.
EffacerBitPlaneCache=1
CTR=1		;counts the number of blitter wait loops
AffLineBlitter=1	;Display's Plot lines using Blitter.
AffObjet3D=1	;Displays the 3D Object.

;Configure the animation of 3D Object
;Depature Angles.
InitAngleAx=20
InitAngleAy=35
InitAngleAz=10
;Axis Increment
PasAngleAX=1
PasAngleAY=1
PasAngleAZ=0
;Center Object Position
offsetX=160	;min 87, maxi 232
offsetZ=87	;mini 87, maxi 168  87=sqr(50^2+50^2+50^2) corner max (50,50,50)


;Registers

VPOSR=$004
VHPOSR=$006
INTENA=$09A
INTENAR=$01C
INTREQ=$09C
INTREQR=$01E
DMACON=$096
DMACONR=$002
BLTAFWM=$044
BLTALWM=$046
BLTAPTH=$050
BLTAPTL=$052
BLTCPTH=$048
BLTDPTH=$054
BLTAMOD=$064
BLTBMOD=$062
BLTCMOD=$060
BLTDMOD=$066
BLTADAT=$074
BLTBDAT=$072
BLTCON0=$040
BLTCON1=$042
BLTSIZE=$058
DIWSTRT=$08E
DIWSTOP=$090
BPLCON0=$100
BPLCON1=$102
BPLCON2=$104
DDFSTRT=$092
DDFSTOP=$094
BPL1MOD=$108
BPL2MOD=$10A
BPL1PTH=$0E0
BPL1PTL=$0E2
BPL2PTH=$0E4
BPL2PTL=$0E6
COLOR00=$180
COLOR01=$182
COLOR02=$184
COLOR03=$186
COP1LCH=$080
COPJMP1=$088
FMODE=$1FC

;------------ Program ----------



DISPLAY_DEPTH=2
DISPLAY_DX=320
DISPLAY_DY=256
DISPLAY_X=$81
DISPLAY_Y=$2C
SCROLL_DX=DISPLAY_DX
SCROLL_X=(DISPLAY_DX-SCROLL_DX)>>1
SCROLL_DY=100
SCROLL_AMPLITUDE=SCROLL_DY-16	;SCROLL_DY-16 gives the amplitude of the possible ordinates of the scroll: [0,SCROLL_DY16]
								;SCROLL_DY Must be even to center on DISPLAY_DY
								;so SCROLL_DY-16 is even
								;The cordinates are computed by (A>>1)*sin which calculates the values [-A,A] when A is even and in [-A+1,A+1] when A is odd
								;Here A=SCROLL_DY-16 so A is even with no correction made.
SCROLL_Y=(DISPLAY_DY-SCROLL_DY)>>1
;SCROLL_SPEED=2
SCROLL_COLOR=$0FFF
SINE_SPEED_FRAME=5
SINE_SPEED_PIXEL=1
LINE_DX=15	;The Number of lines within a straight line : LINE_DX=max (abs(15-0),abs(0,0))
LINE_DY=0	;This is the number of columns from the right : LINE_DY=min (abs(15-0),abs(0,0))
LINE_OCTANT=1
MIRROR_Y=SCROLL_Y+SCROLL_DY	;The Y-Axis Order of the line where the mirror will start(the WAIT to modify BPL1MOD takes place one line before)
MIRROR_COLOR=$000A
MIRROR_SCROLL_COLOR=$000F
SHADOW_DX=2	;included between 0 and 15
SHADOW_DY=2
SHADOW_COLOR=$0777


SCROLL_POS_Y=162
SCROLL_SPEED=1

;COPSIZE=18*4+14*4+4

;---------- Macros ----------

;Wait for the Blitter. when the second operand is an address, BTST only test bits 7-0, treating the first operand as the bit number modulo 8, BTST #14,DMACONR(a5) is equivalent to testing the bit 14%8=6 of the most significant byte of DMANCONR, which corrisponds to BBUSY

WAITBLIT:	MACRO
_waitBlitter0\@
	IFNE CTR
	add.l	#1,BltCTR
	ENDC
	btst #14,DMACONR(a5)
	bne _waitBlitter0\@
_waitBlitter1\@
	IFNE CTR
	add.l	#1,BltCTR
	ENDC
	btst #14,DMACONR(a5)
	bne _waitBlitter1\@
	IFNE CTR
	sub.l	#2,BltCTR
	ENDC
	ENDM


;---------- Initialisations ----------

;STACK Registers

	movem.l d0-d7/a0-a6,-(sp) *** NIV1

;Allocate Chip RAM to 0 for Copper list

	move.l #COPSIZE,d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,copperlist_PTR
	;Calculation of the Bit Planes Pointer from the copper list
	add.l	#CplBitPlanes-CopListDataStart,d0
	move.l	d0,Copperlist_BitPlanes_PTR

;Allocate Chip Ram set for 0 for the Bit Planes - Agnus Denise

	move.l #(DISPLAY_DX*DISPLAY_DY)>>3,d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,bitplaneA

	move.l #(DISPLAY_DX*DISPLAY_DY)>>3,d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,bitplaneB

	move.l #(DISPLAY_DX*DISPLAY_DY)>>3,d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,bitplaneC

; ;Now do the same for the font

	; move.l #256<<5,d0
	; move.l #$10002,d1
	; movea.l $4,a6
	; jsr -198(a6)
	; move.l d0,Font16_PTR

;Shutdown the system

	movea.l $4,a6
	jsr -132(a6)

;Shutdown/Reset Hardware

	lea $dff000,a5
	move.w INTENAR(a5),intena_PTR
	move.w #$7FFF,INTENA(a5)
	move.w INTREQR(a5),intreq_PTR
	move.w #$7FFF,INTREQ(a5)
	move.w DMACONR(a5),dmacon_PTR
	move.w #$07FF,DMACON(a5)


;---------- Creation and Enabling of the copper list ----------


RecopierAdresseBplVersCpl:
	;copy the addresses of the first 2 bitplanes into copperlist
	moveq	#2-1,d1
	move.l 	#bitplaneA,a0
	move.l	#CplBitPlanes,a1	;address of CplBitPlanes
	add.l	#2,a1
.l:
	move.l	(a0)+,d0	;Address the bitplane
	move.w	d0,(a1)
	swap	d0
	add.l	#4,a1
	move.w	d0,(a1)
	add.l	#4,a1
	dbf		d1,.l

	;Transfer Copper List to Chip RAM
	move.l	#COPSIZE/4-1,d0
	move.l	#CopListDataStart,a0
	move.l	copperlist_PTR,a1
.l2:
	move.l	(a0)+,(a1)+
	dbf		d0,.l2

	;Enable Copperlist
	move.l copperlist_PTR,COP1LCH(a5)
	clr.w COPJMP1(a5)
	move.w #$83C0,DMACON(a5)	;DMAEN=1, COPEN=1, BPLEN=1, COPEN=1, BLTEN=1



; ;---------- Converting a 16x16 font from an 8x8 font ----------

; ;Prepare the font data (1st byte = sequence of bits 7 of the 8 lines and bytes of the character, 2nd bytue = sequence of bits 6 of the 8 lines and bytes of the character, etc. : rotation of -90°). Note that with the Blitter it will be neccersary to draw the columns from the last to the first line because of the orentation of the pattern (it would be needed to apply a Y axis symettry to it before to draw from the first to the last line.
	; lea 	font8,a0
	; move.l 	Font16_PTR,a1
	; move.w 	#256-1,d0
; _fontLoop:
	; moveq 	#7,d1		;
; _fontLineLoop:
	; clr.w 	d5
	; clr.w 	d3
	; clr.w 	d4
; _fontColumnLoop:
	; move.b 	(a0,d5.w),d2	;
	; btst 	d1,d2		;Bit D1 is tested
	; beq 	_fontPixelEmpty
	; bset 	d4,d3		;
	; addq.b 	#1,d4
	; bset 	d4,d3
	; addq.b 	#1,d4
	; bra 	_fontPixelNext
; _fontPixelEmpty:
	; addq.b 	#2,d4
; _fontPixelNext:
	; addq.b 	#1,d5
	; btst 	#4,d4
	; beq 	_fontColumnLoop
	; move.w 	d3,(a1)+
	; move.w 	d3,(a1)+
	; dbf 	d1,_fontLineLoop
	; lea 	8(a0),a0
	; dbf 	d0,_fontLoop



;---------- Main Loop ----------

	;A1=PTR on the .w of the column 16x16
	;A5=$DFF000
	;A4=address of the character of the text of display
	;D7=position of the column to display 0.15

	clr.w	D7



_loop:
	IFNE CTR
	move.l	BltCTR,BltWait
	move.l	#0,BltCtr
	ENDC
	;Wait for a full sync / wait for CRT Electron Beam to finish traceing the mask (if using CRT)

	;D0 = loop ctr
_waitVBL:
	move.l VPOSR(a5),d0
	lsr.l #8,d0
	and.w #$01FF,d0
	cmp.w #DISPLAY_Y+DISPLAY_DY,d0
	blt _waitVBL

	;The Following Resgisters cannot be modified
	;A1,A4,A5,D7

	IFNE DEBUGDISPLAYTIME
	move.w #$0F00,COLOR00(a5)
	ENDC

	;The Circular Swapping of bitplanes
	;Registers that cannot be modified.
	;A1,A4,A5,D7
	move.l bitplaneA,d0
	move.l bitplaneB,d1
	move.l bitplaneC,d2
	move.l d1,bitplaneA	;Bitplane Display
	move.l d2,bitplaneB	;Bitplane Construction.
	move.l d0,bitplaneC ;Bitplane erasing

	;D0,D1,D2 free regesters
	;A1,A4,A5,D7 protected.

	;write bitplane addresses in the copperlist
	movea.l	Copperlist_BitPlanes_PTR,a0
	move.w d1,2(a0)
	move.w d1,10(a0)
	swap d1
	move.w d1,6(a0)
	move.w d1,14(a0)

	;A1,A4,A5,D7 protected.

	;writing an 8x8 text
	;A1,A4,A5,D7 not modified
	;A0,A2,A3,D0 to be used.




*** CALCUL 3D ********************************
*
*
	IFNE AffObjet3D

Calcul3D:

	movem.l d0-d7/a0-a6,-(sp)

    ;Viewing Angles.
	move.l	#0,a4
	move.l	#0,a5
	move.l	#0,a6

    ;Increment angle aX
	move.w	AngleAx,a4
	add.w  	#PasAngleAX,a4  ;increment
	cmp.w	#360,a4
	blo     PasModuloIncrementAx
    sub.w   #360,a4
PasModuloIncrementAx:
	move.w	a4,AngleAx

    ;Increment angle aY
	move.w	AngleAY,a5
	add.w  	#PasAngleAY,a5  ;+increment
	cmp.w	#360,a5
	blo     PasModuloIncrementAy
    sub.w   #360,a5
PasModuloIncrementAy:
	move.w	a5,AngleAy

    ;Increment angle aZ
	move.w	AngleAz,a6
	add.w  	#PasAngleAZ,a6 	;increment
	cmp.w	#360,a6
	blo     PasModuloIncrementAz
    sub.w   #360,a6
PasModuloIncrementAz:
	move.w	a6,AngleAz


	;setting table in words so angle*2
	add.w	a5,a5
  	add.w	a4,a4




   ;calculate the points of the table
CalculateEnsemblePointsXYZ:
    lea Points,a0
    lea PointsCalculate,a1
    lea CosinusTbl,A2
    lea SinusTbl,A3


    move.w  #(FinPoints-Points)/6-1,d7

LoopCalculateEnsemblePointsXYZ:
    clr.l   D0
    clr.l   d1
    clr.l   d2
    clr.l   d5
    clr.l   d6

    move.w  (A0)+,d0    ;rho
    move.w  (A0)+,d1    ;teta
    move.w  (A0)+,d2    ;z

	;add angle to TETA
	add.w	a6,d1
	cmp.w	#360,d1
	blo     PasModuloIncrementTeta
    sub.w   #360,d1
PasModuloIncrementTeta:

	bsr     CalculateXYZ

	add.w	#offsetX,d4		;screen location
	add.w	#offsetZ,d1

	move.w  d4,(A1)+    ;x
    move.w  d0,(A1)+    ;y
    move.w  d1,(A1)+    ;z
    dbf     d7,LoopCalculateEnsemblePointsXYZ
FinCalculateEnsemblePointsXYZ:

	bra 	FinCalcul3D


CalculateXYZ:
    ;Start   D0=rho plan xy, D1=Teta+aZ xy, D2=Z
    ;           D3=aX, D4=aY
    ;           A2=ptrTableCOS, A3=ptrTableSIN
    ;Exit :   D0=x, D1=z, D2=y
    ;

    ;************************
    ;This is used : d0=rho, d1=aZ, d2=Z, a2=cos, a3=sin, A4=aX, A5=aY

    add.w   d1,d1   ;table TRIGO de mots, donc angle*2

    ;************************
    ;rotation axe Z (plan XY)
    ;x1=rho*cos(teta+aZ)        ;d5=cos(d1), d5=d0*d5
    ;y1=rho*sin(teta+aZ)        ;d1=sin(d1), d1=d0*d1

    move.w  (a2,d1),d5
    muls  d0,d5         ;d5=x1
    lsr.l  #7,d5
    lsr.l  #7,d5

    move.w  (a3,d1),d1
    muls  d0,d1         ;d1=y1
    lsr.l  #7,d1
    lsr.l  #7,d1

    ;************************
    ;These are used : d1=y1, d2=Z, d5=x1, a2=cos, a3=sin, A4=aX, A5=aY
    ;************************
    ;rotation axe X (plan YZ)   ;D4=cos(A4), d3=sin(A4)
    ;y2=y1*cos(aX)-z*sin(ax)    ;d0=D4, d0=d1*d0, d6=d3, d6=d2*d6, d0=d0-d6
    ;z1=y1*sin(aX)+z*cos(aX)    ;d3=d1*d3, d4=d2*d4, d3=d3+d4

    ;moveq   #0,d4
    ;moveq   #0,d3

	move.w  (a2,A4),d4  ;a4=cos(aX)
    move.w  (a3,A4),d3  ;d3=sin(ax)

    move.w  d4,d0	;c
    move.w  d3,d6	;s

    muls    d1,d0	;y1*cos
    muls    d2,d6	;z*sin
    sub.l   d6,d0   ;y2=y1*cos-z*sin
    lsr.l   #7,d0
    lsr.l   #7,d0

    muls    d1,d3	;y*sin
    muls    d2,d4	;z*cos
    add.l   d4,d3   ;z1=y*sin+z*cos
    lsr.l   #7,d3
    lsr.l   #7,d3

    ;************************
    ;These are used : d0=y2, d3=z1, d5=x1, a2=cos, a3=sin, A5=aY
    ;************************
    ;rotation axe Y (plan ZX)   ;d6=cos(A5), d4=sin(A5)
    ;z2=z1*cos(aY)-x1*sin(aY)   ,d1=d6, d1=d3*d1, d2=d4, d2=d5*d2, d1=d1-d2
    ;x2=z1*sin(aY)+x1*cos(aY)   ;d6=d5*d6, d4=d3*d4, d4=d6+d4

    moveq   #0,d4
    moveq   #0,d6

    move.w  (a2,A5),d6  ;cos(aY)
    move.w  (a3,A5),d4  ;sin(aY)

    move.w  d6,d1
    move.w  d4,d2

    muls    d3,d1	;z1*cos
    muls    d5,d2	;x1*sin
    sub.l   d2,d1   ;z2=z1*cos-x1*sin
    lsr.l   #7,d1
    lsr.l   #7,d1

    muls    d3,d4	;z1*sin
    muls    d5,d6	;x1*cos
    add.l   d6,d4   ;x2=x1*cos+z1*sin
    lsr.l   #7,d4
    lsr.l   #7,d4

    ;************************
    ;These are used : d0=y2, d1=z2, d4=x2

    rts



AngleAx:		dc.w	InitAngleAx
AngleAy:		dc.w	InitAngleAy
AngleAz:		dc.w	InitAngleAz


Points:    ;Spherical Coordinates : rho (length) plan xy , Teta (Az), z
P:
; rho,Teta,z   ;x,y,z
P01: dc.w 70,45,-50   ;50,50,-50
P02: dc.w 70,45,50   ;50,50,50
P03: dc.w 70,135,50   ;-50,50,50
P04: dc.w 70,225,50   ;-50,-50,50
P05: dc.w 70,225,-50   ;-50,-50,-50
P06: dc.w 70,315,-50   ;50,-50,-50
P07: dc.w 70,315,50   ;50,-50,50
P08: dc.w 70,135,-50   ;-50,50,-50
P09: dc.w 50,90,50   ;0,50,50
P10: dc.w 50,0,50   ;50,0,50
P11: dc.w 70,45,0   ;50,50,0
FinPoints:


Lines:
    dc.w    P03-P,P04-P
    dc.w    P04-P,P07-P
    dc.w    P04-P,P05-P
    dc.w    P05-P,P06-P
    dc.w    P06-P,P07-P
    dc.w    P01-P,P06-P
    dc.w    P05-P,P08-P
    dc.w    P08-P,P01-P
    dc.w    P08-P,P03-P
*    dc.w    P07-P,P01-P
*    dc.w    P03-P,P01-P
*    dc.w    P03-P,P07-P
	dc.w	P03-P,P09-P
	dc.w	P07-P,P10-P
	dc.w	P01-P,P11-P
	dc.w	P10-P,P11-P
	dc.w	P11-P,P09-P
	dc.w	P09-P,P10-P

FinLines:


PointsCalculate:
    ;x.b, y.b, z.b
    ds.b    (FinPoints-Points)

;----- Trigernometry Tables -----
SinusTbl:
   dc.w   0,285,571,857,1142,1427,1712,1996,2280,2563   ;Sin(0) where Cos(-90)
   dc.w   2845,3126,3406,3685,3963,4240,4516,4790,5062,5334   ;Sin(10) where Cos(-80)
   dc.w   5603,5871,6137,6401,6663,6924,7182,7438,7691,7943   ;Sin(20) where Cos(-70)
   dc.w   8191,8438,8682,8923,9161,9397,9630,9860,10086,10310   ;Sin(30) where Cos(-60)
   dc.w   10531,10748,10963,11173,11381,11585,11785,11982,12175,12365   ;Sin(40) where Cos(-50)
   dc.w   12550,12732,12910,13084,13254,13420,13582,13740,13894,14043   ;Sin(50) where Cos(-40)
   dc.w   14188,14329,14466,14598,14725,14848,14967,15081,15190,15295   ;Sin(60) where Cos(-30)
   dc.w   15395,15491,15582,15668,15749,15825,15897,15964,16025,16082   ;Sin(70) where Cos(-20)
   dc.w   16135,16182,16224,16261,16294,16321,16344,16361,16374,16381   ;Sin(80) where Cos(-10)
CosinusTbl:
   dc.w   16384,16381,16374,16361,16344,16321,16294,16261,16224,16182   ;Sin(90) where Cos(0)
   dc.w   16135,16082,16025,15964,15897,15825,15749,15668,15582,15491   ;Sin(100) where Cos(10)
   dc.w   15395,15295,15190,15081,14967,14848,14725,14598,14466,14329   ;Sin(110) where Cos(20)
   dc.w   14188,14043,13894,13740,13582,13420,13254,13084,12910,12732   ;Sin(120) where Cos(30)
   dc.w   12550,12365,12175,11982,11785,11585,11381,11173,10963,10748   ;Sin(130) where Cos(40)
   dc.w   10531,10310,10086,9860,9630,9397,9161,8923,8682,8438   ;Sin(140) where Cos(50)
   dc.w   8191,7943,7691,7438,7182,6924,6663,6401,6137,5871   ;Sin(150) where Cos(60)
   dc.w   5603,5334,5062,4790,4516,4240,3963,3685,3406,3126   ;Sin(160) where Cos(70)
   dc.w   2845,2563,2280,1996,1712,1427,1142,857,571,285   ;Sin(170) where Cos(80)
   dc.w   0,-286,-572,-858,-1143,-1428,-1713,-1997,-2281,-2564   ;Sin(180) ou Cos(90)
   dc.w   -2846,-3127,-3407,-3686,-3964,-4241,-4517,-4791,-5063,-5335   ;Sin(190) where Cos(100)
   dc.w   -5604,-5872,-6138,-6402,-6664,-6925,-7183,-7439,-7692,-7944   ;Sin(200) where Cos(110)
   dc.w   -8193,-8439,-8683,-8924,-9162,-9398,-9631,-9861,-10087,-10311   ;Sin(210) where Cos(120)
   dc.w   -10532,-10749,-10964,-11174,-11382,-11586,-11786,-11983,-12176,-12366   ;Sin(220) where Cos(130)
   dc.w   -12551,-12733,-12911,-13085,-13255,-13421,-13583,-13741,-13895,-14044   ;Sin(230) where Cos(140)
   dc.w   -14189,-14330,-14467,-14599,-14726,-14849,-14968,-15082,-15191,-15296   ;Sin(240) where Cos(150)
   dc.w   -15396,-15492,-15583,-15669,-15750,-15826,-15898,-15965,-16026,-16083   ;Sin(250) where Cos(160)
   dc.w   -16136,-16183,-16225,-16262,-16295,-16322,-16345,-16362,-16375,-16382   ;Sin(260) where Cos(170)
   dc.w   -16384,-16382,-16375,-16362,-16345,-16322,-16295,-16262,-16225,-16183   ;Sin(270) where Cos(180)
   dc.w   -16136,-16083,-16026,-15965,-15898,-15826,-15750,-15669,-15583,-15492   ;Sin(280) where Cos(190)
   dc.w   -15396,-15296,-15191,-15082,-14968,-14849,-14726,-14599,-14467,-14330   ;Sin(290) where Cos(200)
   dc.w   -14189,-14044,-13895,-13741,-13583,-13421,-13255,-13085,-12911,-12733   ;Sin(300) where Cos(210)
   dc.w   -12551,-12366,-12176,-11983,-11786,-11586,-11382,-11174,-10964,-10749   ;Sin(310) where Cos(220)
   dc.w   -10532,-10311,-10087,-9861,-9631,-9398,-9162,-8924,-8683,-8439   ;Sin(320) where Cos(230)
   dc.w   -8193,-7944,-7692,-7439,-7183,-6925,-6664,-6402,-6138,-5872   ;Sin(330) where Cos(240)
   dc.w   -5604,-5335,-5063,-4791,-4517,-4241,-3964,-3686,-3407,-3127   ;Sin(340) where Cos(250)
   dc.w   -2846,-2564,-2281,-1997,-1713,-1428,-1143,-858,-572,-286   ;Sin(350) where Cos(260)
   dc.w   -1,285,571,857,1142,1427,1712,1996,2280,2563   ;Sin(360) where Cos(270)
   dc.w   2845,3126,3406,3685,3963,4240,4516,4790,5062,5334   ;Sin(370) where Cos(280)
   dc.w   5603,5871,6137,6401,6663,6924,7182,7438,7691,7943   ;Sin(380) where Cos(290)
   dc.w   8191,8438,8682,8923,9161,9397,9630,9860,10086,10310   ;Sin(390) where Cos(300)
   dc.w   10531,10748,10963,11173,11381,11585,11785,11982,12175,12365   ;Sin(400) where Cos(310)
   dc.w   12550,12732,12910,13084,13254,13420,13582,13740,13894,14043   ;Sin(410) where Cos(320)
   dc.w   14188,14329,14466,14598,14725,14848,14967,15081,15190,15295   ;Sin(420) where Cos(330)
   dc.w   15395,15491,15582,15668,15749,15825,15897,15964,16025,16082   ;Sin(430) where Cos(340)
   dc.w   16135,16182,16224,16261,16294,16321,16344,16361,16374,16381   ;Sin(440) where Cos(350)


FinCalcul3D:
	movem.l (sp)+,d0-d7/a0-a6

	ENDC
*
*
*** FIN CALCUL 3D ***************************






*** TRACE WITH BLITTER ********************************
*
*
	IFNE AffLineBlitter
	movem.l d0-d7/a0-a6,-(sp)
	;clr.l	d7
	clr.l	d0/d6

	WAITBLIT
	move.w	#40,BLTCMOD(A5)	;=width of pixel plane in bytes
	move.w	#40,BLTDMOD(A5)	;=pixel plane width in bytes
	move.w	#$8000,BLTADAT(A5)
	move.w	#$FFFF,BLTBDAT(A5) 	:right texture, $FFFF = max
	move.w	#$FFFF,BLTAFWM(A5)	;=$FFFF
	move.w	#$FFFF,BLTALWM(A5)	;=$FFFF
	lea	TableOctant(pc),a0

	move.l	bitplaneB,A1	;A1 and A2 used as a copy in loop.




;trace of the 3D Object.
	IFNE AffObjet3D ************************** TRACER OBJET 3D
	lea		PointsCalculate,a3 ******* DEBUG
	lea		Lines,a4

	move.w  #((Endlines-lines)/4)-1,d7
LoopTracer3D:
	moveq.l	#0,d0
	moveq.l	#0,d1
	moveq.l	#0,d2
	moveq.l	#0,d3

	move.w	(a4)+,d3	;first offset point
	move.w	(a3,d3),d0	;x1
	move.w	4(a3,d3),d1	;y1 (z)

	move.w	(a4)+,d3	;second offset point
	move.w	(a3,d3),d2	;x2
	move.w	4(a3,d3),d3	;y2 (z)

	bsr		_TracerLine

	dbf	d7,LoopTracer3D


	;traces axis of rotation
	IFNE DEBUGDISPLAYTIME ************************** DEBUG

	lea	CosinusTbl,a3
	lea	SinusTbl,A4

	lea		AngleAx,a6

	moveq.l	#3-1,d7
LoopAffAngles:
	move.l	#290,d0	;x1
	move.l	#30,d1	;y1
	move.l	#20,d4	;rayon

	;ajout du pas y
	moveq.l	#0,d5
	move.w	d7,d5
	muls	#40,d5
	add.w	d5,d1

	moveq.l	#0,d5
	move.w	(a6)+,d5	;angle AX, AY, AZ
	add.w	d5,d5		;angle table

	move.w	(a3,d5),d2	;peer addressing
	muls	d4,d2
	lsr.l	#7,d2
	lsr.l	#7,d2 ;x2
	add.l	d0,d2

	move.w	(a4,d5),d3	;peer addressing
	muls	d4,d3
	lsr.l	#7,d3
	lsr.l	#7,d3	;y2
	add.l	d1,d3

	bsr	_TracerLine

	dbf	d7,LoopAffAngles

	ENDC ************************** FIN DEBUG


	movem.l (sp)+,d0-d7/a0-a6

	bra	_FinTracerBlitter

	; a:	dc.l	0
	; x1:	dc.l	0
	; y1:	dc.l	0
	; x2:	dc.l	0
	; y2:	dc.l	0

	ENDC ************************** FIN TRACE OBJET 3D



_TracerLine:
 ; ------------------------------
 ; BIT# BLTCON0     BLTCON1
 ; ---- -------     -------
 ; 15   START3      TEXTURE3
 ; 14   START2      TEXTURE2
 ; 13   START1      TEXTURE1
 ; 12   START0      TEXTURE0
 ; 11    1              0
 ; 10    0              0
 ; 09    1              0
 ; 08    1              0
 ; 07   LF7             0
 ; 06   LF6            SIGN
 ; 05   LF5             0 (Reserved)
 ; 04   LF4            SUD
 ; 03   LF3            SUL
 ; 02   LF2            AUL
 ; 01   LF1            SING
 ; 00   LF0            LINE(=1) = LINE DRAW

	;---- Calculate Octant (Reflecting Quadrant) ----
	;Arguments (d0=x1,d1=y1,d2=x2,d3=y2)
	;These are used : d4,a0,a1
	;d0..d4,A0

	moveq.l	#0,d4	;4 cycles
	sub.w	d1,d3	;d3=dy=y2-y1
	bpl.b	y2_sup_y1
	bset	#2,d4	;8 cycles
	neg.w	d3		;d3=abs(dy)
y2_sup_y1:
	sub.w	d0,d2	;d2=dx=x2-x1
	bpl.b	x2_sup_x1
	bset	#1,d4
	neg.w	d2		;d2=abs(dx)
x2_sup_x1:
	cmp.w	d3,d2	;D3=dy vs D2=dx
	bpl.b	dX_sup_dY
	bset	#0,d4
	exg		d2,d3
dX_sup_dY:

	move.b	(a0,d4),d5	;octant in D5

	;d3=dy=petit delta
	;d2=dx=GRAND DELTA

	;---- Depature Address ----
	;D0=x1, D1=y1
	;d2=dx,	d3=dY

	move.l	a1,a2	;BitplaneB ;4 cycles

	ror.l   #4,d0   ;move upper four bits into hi
    add.w	d0,d0	;d0=d0*2
	add.l	d0,a2	;bitplaneB+x1/8
					;The addressing being 24 bits (68000 can address 24bits technically spite being 16 bit processor) the 4 bits in HI Memory do not influence each other.

	;d1=y1
	;36 cycles
	lsl.w	#3,d1	;d1=y1*8
	add.w	d1,a2	;A2=bitplaneB+(x1/8)+y1*8
	add.w	d1,d1	;d1=y1*16
	add.w	d1,d1	;d1=y1*32
	add.l	d1,a2	;a2=bitplaneB+(x1/8)+y1*40 = departure address

	moveq.l	#0,d6	;clr.l	d6	;,d1

	;d3=dY
	add.w   d3,d3	;d3=dy*2
    add.w   d3,d3	;d3=dy*4	;;lsl.w	#2,d3		;10 cycles
	move.w	D3,D4	;D4=4*dy
	move.w	d2,d1	;d1=d2=dX
	add.w	d1,d1	;lsl.w	#1,d1	;D1=2*dx

	WAITBLIT
	move.w	d3,BLTBMOD(A5)	;=4*dy
	sub.w	d1,D3	;d3=4*dy - 2*dx
	roxl.w	#7,D6	;si D3<0, set the SIGN bit to 1 in BLTCON1

	move.l	d3,BLTAPTH(A5)	;=4*dY-2*dX,

	add.w	d1,d1	;lsl.w	#1,d1	;D1=2*2*dx
	sub.w	D1,D4	;d4=4*dy-4*dx
	move.w	d4,BLTAMOD(A5)	;=4*dy-4*dx

	swap	d0
	or.w	d6,D0
	or.w	#$0BCA,D0

	move.w	d0,BLTCON0(A5)	;bits 15,14,13,12  = starting point of the line
				;bit 11,10,9,8 = %1011
				;bit 7..0 = $CA
	or.w	D6,D5	;%xxxx000000xxxx01

	;bset	#1,D5	;to draw a single point per line
	;register it directly in the Octant Table.

	move.l	a2,BLTCPTH(A5)	;Address of the starting point of line
	move.l	a2,BLTDPTH(A5)	;idem
	move.w	d5,BLTCON1(A5)	;bits 15,14,13, 12  = starting points from the right.
				;bits 11..7 = %00000
				;bit 6 = 1 si 4*dY-2*dX<0
				;bit 5 = 0
				;bits 4,3,2 = code Octant
				;bit 1 = 1, 1 dot by line
				;bit 0 = 1 right trace mode

	add.w	#$01,d2	;dx+1
	lsl.w	#6,d2	;(dx+1)*64 ; 20 cycles
	add.w	#$02,d2	;(dx+1)*64+2
	move.w	d2,BLTSIZE(A5)	;c'est parti = (dX+1)*64+2

	rts

TableOctant:	;3 first bits=octant, bit1 = 1 si 1 pt /line, bit 0=1 line trace mode
	dc.b	%10001
	dc.b	%00001
	dc.b	%10101
	dc.b	%01001
	dc.b	%11001
	dc.b	%00101
	dc.b	%11101
	dc.b	%01101
	even


	ENDC
	**
	**
	**** Finish Trace Using BLITTER *******************

	IFNE CTR
BltWait:	dc.l	0
BltCtr:		dc.l	0
	ENDC

_FinTracerBlitter:



	*** Clear bitplane cache ************************
	IFNE EffacerBitPlaneCache
	WAITBLIT
	move.w	#0,BLTDMOD(a5)
	move.w	#$0000,BLTCON1(a5)
	move.w	#%0000000100000000,BLTCON0(a5)
	move.l	bitplaneC,BLTDPTH(a5)
	move.w	#(DISPLAY_DX>>4)!(DISPLAY_DY<<6),BLTSIZE(a5)
	ENDC

	IFNE DEBUGDISPLAYTIME
	move.w	#$00F0,COLOR00(a5)
	ENDC


;********** DEBUGDISPLAYTIME (start) **********
;Displays in decimal, the number of lines used since the end of the screen (from the line (DISPLAY_Y+DISPLAY_DY included)
	;The frame ends in DISPLAY_Y+DISPLAY_DY-1
	;The time is therefore countered in the number of lines from DISPLAY_Y+DISPLAY_DY included
	IFNE DEBUGDISPLAYTIME
	movem.l	d0-d2/a0-a3,-(sp)
	clr.w	d0
	move.l	VPOSR(a5),d0
	lsr.l	#8,d0
	and.w	#$01FF,d0
	cmp.w	#DISPLAY_Y+DISPLAY_DY,d0
	bge 	_timeBelowBitplanes
	;moved to the top of the screen.
	add.w 	#1+312-(DISPLAY_Y+DISPLAY_DY-1),d0	;312 is the lowest line the electron beam can trace resolution wise.
	bra 	_timeDisplayCounter
_timeBelowBitplanes:
	;bottom of the screen.
	sub.w	#DISPLAY_Y+DISPLAY_DY-1,d0
_timeDisplayCounter:
;=>d0.w = # lines taken by the calculations to display.
	and.l	#$0000FFFF,d0
	moveq	#0,d1
	moveq	#3-1,d2
_timeLoopNumber:
	divu	#10,d0		;=> d0=remainder:quotient of the division of d0 with 32 bits.
	swap	d0
	add.b	#$30-$20,d0	;ASCII Code of "0" minus start in font8 ($20)
	move.b	d0,d1
	lsl.l	#8,d1
	clr.w	d0
	swap	d0
	dbf 	d2,_timeLoopNumber
	divu 	#10,d0		;=> d0=remainder: quotient of the division of d0 with 32 bits.
	swap 	d0
	add.b	#$30-$20,d0	;ASCII Code of "0" minus start offset in font8($20)
	move.b	d0,d1
	;=> d1 : continuation of the 4 ASCII offsets in the font of 4 digits/characters to be displayed, but in the opposite direction(eg. 123 => "3210")
	lea 	font8,a0
	movea.l	bitplaneB,a1
	moveq 	#4-1,d0
_timeLoopDisplay:
	clr.w 	d2
	move.b 	d1,d2
	lsl.w 	#3,d2
	lea 	(a0,d2.w),a2
	move.l 	a1,a3
	moveq	#8-1,d2
_timeLoopDisplayChar:
	move.b	(a2)+,(a3)
	lea 	DISPLAY_DX>>3(a3),a3
	dbf 	d2,_timeLoopDisplayChar
	lea 	1(a1),a1
	lsr.l	#8,d1
	dbf		d0,_timeLoopDisplay
	movem.l	(sp)+,d0-d2/a0-a3
	ENDC

	;********** DISPLAYTIME (end) **********

	;Test the pressure of the left mouse button.

	btst	#6,$bfe001
	bne		_loop



_loopEnd:
	WAITBLIT

;---------- Finalisations ----------


exit:

;Reset the hardware

	move.w #$7FFF,INTENA(a5)
	move.w #$7FFF,INTREQ(a5)
	move.w #$07FF,DMACON(a5)

;Restore Hardware

	move.w dmacon_PTR,d0
	bset #15,d0
	move.w d0,DMACON(a5)
	move.w intreq_PTR,d0
	bset #15,d0
	move.w d0,INTREQ(a5)
	move.w intena_PTR,d0
	bset #15,d0
	move.w d0,INTENA(a5)

;Restore the Copper List

	lea graphicslibrary,a1
	movea.l $4,a6
	jsr -408(a6)
	move.l d0,a1
	move.l 38(a1),COP1LCH(a5)
	clr.w COPJMP1(a5)
	jsr -414(a6)

;Restore the system

	movea.l $4,a6
	jsr -138(a6)

;Free the memory.

	; movea.l Font16_PTR,a1
	; move.l #256<<5,d0
	; movea.l $4,a6
	; jsr -210(a6)
	movea.l bitplaneA,a1
	move.l #(DISPLAY_DX*DISPLAY_DY)>>3,d0
	movea.l $4,a6
	jsr -210(a6)
	movea.l bitplaneB,a1
	move.l #(DISPLAY_DX*DISPLAY_DY)>>3,d0
	movea.l $4,a6
	jsr -210(a6)
	movea.l bitplaneC,a1
	move.l #(DISPLAY_DX*DISPLAY_DY)>>3,d0
	movea.l $4,a6
	jsr -210(a6)
	movea.l copperlist_PTR,a1
	move.l #COPSIZE,d0
	movea.l $4,a6
	jsr -210(a6)

;Unstack the Register

	movem.l (sp)+,d0-d7/a0-a6
	rts

;---------- Data ----------

graphicslibrary:
	DC.B "graphics.library",0
	EVEN
font8:
	INCBIN "sources:sinescroll/font8.fnt"	;32 à 127
	EVEN



TEXT_POS:			dc.l	0
dmacon_PTR:			DC.w	0
intena_PTR:			DC.w	0
intreq_PTR:			DC.w	0
scrollColumn:			DC.W	0
scrollChar:			DC.W	0
angle:				DC.W	0
copperlist_PTR:			DC.L 	0
Copperlist_BitPlanes_PTR:	dc.l	0
Font16_PTR:			DC.L 	0
bitplaneA:			DC.L 	0
bitplaneB:			DC.L 	0
bitplaneC:			DC.L 	0




********************* COPPER LIST *********************

CopListDataStart:
	;Configure the screen
	dc.w DIWSTRT,(DISPLAY_Y<<8)!DISPLAY_X
	dc.w DIWSTOP,((DISPLAY_Y+DISPLAY_DY-256)<<8)!(DISPLAY_X+DISPLAY_DX-256)
	dc.w BPLCON0,(DISPLAY_DEPTH<<12)!$0200
	dc.w BPLCON1,SHADOW_DX<<4
	dc.w BPLCON2,0
	dc.w DDFSTRT,((DISPLAY_X-17)>>1)&$00FC
	dc.w DDFSTOP,((DISPLAY_X-17+(((DISPLAY_DX>>4)-1)<<4))>>1)&$00FC	;What is comming back? ((DISPLAY_X-17+DISPLAY_DX-16)>>1)&$00FC si DISPLAY_DX est multiple de 16
	dc.w BPL1MOD,0
	dc.w BPL2MOD,0

;Bitplane Address

CplBitPlanes:
	dc.w BPL1PTL,0
	dc.w BPL1PTH,0
	dc.w BPL2PTL,0
	dc.w BPL2PTH,0

;Couleurs

	IFNE DEBUGDISPLAYTIME
	dc.w $0186,0		;COLOR04 not used, to neutralise modification of COLOR00...
	ELSE
	dc.w COLOR00,0
	ENDC
	dc.w COLOR01,SCROLL_COLOR
	dc.w COLOR02,SHADOW_COLOR
	dc.w COLOR03,SCROLL_COLOR

;ECS and AGA Chipset Compatibility

	dc.w FMODE,$0000

;Shadow and Mirror

	dc.w ((DISPLAY_Y+SCROLL_Y+SHADOW_DY-1)<<8)!$0001,$FF00
	dc.w BPL2MOD,-SHADOW_DY*(DISPLAY_DX>>3)

	dc.w ((DISPLAY_Y+SCROLL_Y+SHADOW_DY)<<8)!$0001,$FF00
	dc.w BPL2MOD,0
	dc.w BPLCON1,SHADOW_DX<<4

	dc.w ((DISPLAY_Y+MIRROR_Y-1)<<8)!$0001,$FF00
	dc.w BPL1MOD,-(DISPLAY_DX>>3)
	dc.w BPL2MOD,(SHADOW_DY-1)*(DISPLAY_DX>>3)

	dc.w ((DISPLAY_Y+MIRROR_Y)<<8)!$0001,$FF00
	dc.w BPLCON1,$0000
	dc.w BPL1MOD,-(DISPLAY_DX>>2)
	dc.w BPL2MOD,-(DISPLAY_DX>>2)

	IFNE DEBUGDISPLAYTIME
	dc.w $0188,MIRROR_COLOR	;COLOR04 is not used, to neutralise in anyway the modification of COLOR00
	ELSE
	dc.w COLOR00,MIRROR_COLOR
	ENDC

	dc.w COLOR03,MIRROR_SCROLL_COLOR
;Finish
	dc.l 	$FFFFFFFE
	dc.l	$00c0ffEE
CopListDataEnd:

COPSIZE=CopListDataEnd-CopListDataStart
