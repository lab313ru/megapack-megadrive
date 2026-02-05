;MEGAUNPK - Megadrive MEGAPACK unpacker (c) Jon Menzies
;* all code PC relative please! *

;opt o1+
;opt o2+
;opt p+
;opt d+

max_colsets equ 512


inword equr d7 ;{hi word}
inbits equr d6 ;{byte}

;a6 is frame pointer
sourceadr equr a5
destadr equr a4

rangeadr equr a3
minbits equ -128 ;+1
addifhi equ +127 ;+1 {first byte is last byte of radr_minbits (8)}

tabadr equr a2
bitmask equ 0
bitcount equ 32

otheradr equr a1

tables_size equ 32+256+256+256+(256*8)


;(could put getbits routine adr in areg to save 2 clocks per call)


chnum equ -2
chi equ -4
colset equ -6
vbits equ -8

var_bytes equ 8


colset_endofs equ -var_bytes


getqbit macro ;MUST guarantee top bit of inword is clear
 clr.w inword
 subq.b #1,inbits
 bhs.s .ok\@
 move.w (sourceadr)+,inword
 swap.w inword
 moveq #15,inbits
.ok\@ add.l inword,inword
endm




;**** entry point at start ****
;move.l a0,sourceadr
;move.l a1,destadr

;bsr init_packer
;lea packdata(pc),sourceadr
;lea destdata,destadr
;bsr mega_unpack
;rts



;**** get1bit ****

get1bit
;uses nothing
;result in carry

 subq.b #1,inbits
 blo.s .no_bits
 clr.w inword
 add.l inword,inword

 rts
.no_bits
 move.w (sourceadr)+,inword
 swap.w inword
 moveq #15,inbits
 add.l inword,inword

 rts





;**** getbits ****

;uses d0
;d0.b=#bits{0..16}
;return result in inword.w

getbits
 sub.b d0,inbits
 blo.s .not_enough

 clr.w inword
 rol.l d0,inword

 rts


.not_enough
 add.b d0,inbits
 move.w (sourceadr)+,inword
 swap.w inword
 rol.w inbits,inword
 sub.b inbits,d0
 rol.l d0,inword
 moveq #16,inbits
 sub.b d0,inbits

 rts


;**** getstream ****

;d1.w=range{257..1024}

bigstream
;range is 257..1024 {or more}

 subq.w #1,d1

 moveq #0,d2
 move.b d1,d2
 addq.w #1,d2 ;(w!)

 lsr.w #8,d1
 addq.w #1,d1
 bsr.s getstream

 move.w d2,d1
 subq.w #1,inword
 blo.s getstream

 asl.w #8,inword
 add.w inword,d2
 moveq #8,d0
 bsr.s getbits
 add.w d2,inword

 rts

getbigstream
;uses d0..d2
 cmp.w #256,d1
 bhi.s bigstream

getstream
;uses d0..d1
;d1.w=range{1..256}
;result in inword.w

 move.b minbits(rangeadr,d1.w),d0
 bsr.s getbits
 cmp.b addifhi(rangeadr,d1.w),inword
 bhi.s hiside
 rts

hiside
 subq.b #1,inbits
 blo.s .no_bits
 rol.l #1,inword
 sub.b addifhi(rangeadr,d1.w),inword
 subq.w #1,inword

 rts
.no_bits
 swap.w inword
 move.w (sourceadr)+,inword
 add.l inword,inword
 swap.w inword
 moveq #15,inbits

 sub.b addifhi(rangeadr,d1.w),inword
 subq.w #1,inword

 rts


;**** pixstream ****

mpixstream
;uses d0..d1/d4.w/d5.w   (preserves high of d4 and d5)
;returns pixel in d0.w
;d1.w=colour*2
;create tcols minus (d1=colour*2)
 move.w colset(a6),d5
 and.w bitmask(tabadr,d1.w),d5

pixstream
;d5=tcols
;count bits to calc range
 clr.w d4
 move.b d5,d4
 move.b bitcount(tabadr,d4.w),d4

 move.w d4,-(a7)

 move.w d5,d0
 lsr.w #8,d0
 add.b bitcount(tabadr,d0.w),d4

;* get streamed index *
;*getstream*
;d4.w=range{1..16}
;result in inword.w

 move.b minbits(rangeadr,d4.w),d0

;*getbits*
 sub.b d0,inbits
 bhs.s .enough

;not_enough
 add.b d0,inbits
 move.w (sourceadr)+,inword
 swap.w inword
 rol.w inbits,inword
 sub.b inbits,d0
 moveq #16,inbits
 sub.b d0,inbits
 bra.s .rol

.enough
 clr.w inword
.rol rol.l d0,inword


 cmp.b addifhi(rangeadr,d4.w),inword
 bls.s .loside
;hiside
 subq.b #1,inbits
 bhs.s .enough2
;no_bits
 swap.w inword
 move.w (sourceadr)+,inword
 swap.w inword
 moveq #15,inbits
.enough2
 rol.l #1,inword
 sub.b addifhi(rangeadr,d4.w),inword
 subq.w #1,inword

.loside
.got_index

 move.w inword,d0
 sub.w (a7)+,d0 ;(index)
;cmp.w (a7)+,inword ;(index)
 bhs.s .hicol
.locol
 and.w #$ff,d5
 asl.w #3,d5
 add.w inword,d5
 moveq #0,d0
 move.b (a0,d5.w),d0
 rts

.hicol
 clr.b d5
 lsr.w #5,d5
 add.w d0,d5
 moveq #8,d0
 add.b (a0,d5.w),d0
 rts

;using table=9.5
;1+1+(1+2)*4+(.5+2.5)*2+(1+1)=22.0

;mega.s8 41,41,47,53,44,57
;mega.s10 39,39,45,52,42,55



;**** unpack similar character ****

unpack_sim

;** which other char? **

 move.w chi(a6),d1
;cmp.w #max_backchars,d1
;bls.s .backok
;move.w #max_backchars,d1
.backok
 bsr getbigstream
 not.w inword ;[-1..-chi]
 asl.w #5,inword
 lea (destadr,inword.w),otheradr

;** get vbits/hbits **

;vbits
 clr.w d3
 bsr get1bit
 bcc.s .vh0

 moveq #15,d1
 bsr getstream
 not.b inword
 asl #4,inword
 move.b inword,d3
.vh0
 bsr get1bit
 bcc.s .vl0

 moveq #15,d1
 or.b d1,d3
 bsr getstream
 eor.b inword,d3
.vl0
 move.b d3,vbits(a6)

;hbits
 clr.w d4
 bsr get1bit
 bcc.s .hh0

 moveq #15,d1
 bsr getstream
 not.b inword
 asl #4,inword
 move.b inword,d4
.hh0
 bsr get1bit
 bcc.s .hl0

 moveq #15,d1
 or.b d1,d4
 bsr getstream
 eor.b inword,d4
.hl0

;(vbits in vbits(a6), hbits in d4)

;** unpack sim body **

 or.w #$700,d4
.yloop
;hbit row?
 add.b d4,d4
 bcs.s .whole_row

;the hard way

 clr.w inword

;make personal vbits
 move.b vbits(a6),d2
 moveq #$fe,d0

;use vbits raw if this sole row in hbits
 cmp.b d0,d4
 beq.s .skipvlb

 moveq #7,d1
.vlb rol.b #1,d2
 bcs.s .got
 cmp.b d0,d2
 beq.s .got
 getqbit
 bcc.s .got
 addq.b #1,d2
.got dbra d1,.vlb
.skipvlb

;start xloop

 swap.w d4 ;use as temp (keep high word!)
 moveq #3,d3 ;for xloop

.xloop

;pixel pair
 add.b d2,d2
 bcs.s .1x
.0x

;even dif
;get other*2 in d1.w
 move.w #$f0,d1
 and.b (otheradr),d1
 lsr.w #3,d1
;get pixel
 bsr mpixstream

 asl.b #4,d0

;d1:=odd other
 moveq #$0f,d1
 and.b (otheradr)+,d1
;00 or 01?
 add.b d2,d2
 bcs.s .01
.00
 move.w d0,d5
 swap.w d5
;odd dif
;d1:=other*2
 add.w d1,d1
;get pixel
 bsr mpixstream

 swap.w d5
 or.w d0,d5
 move.b d5,(destadr)+

 dbra d3,.xloop
 swap.w d4 ;restore hbits/ycnt
 sub.w #$100,d4
 bcc.s .yloop
 rts


.whole_row
 addq.b #1,d4  ;emulate rol
 move.l (otheradr)+,(destadr)+
 sub.w #$100,d4
 bcc.s .yloop
 rts

.1x
 add.b d2,d2
 bcs.s .11
.10
;d1:=other*2
 moveq #$0f,d1
 and.b (otheradr),d1
 add.w d1,d1
;get pixel
 bsr mpixstream

 moveq #$f0,d1
 and.b (otheradr)+,d1
.01
 or.b d1,d0
 move.b d0,(destadr)+

 dbra d3,.xloop
 swap.w d4 ;restore hbits/ycnt
 sub.w #$100,d4
 bcc .yloop
 rts

.11
 move.b (otheradr)+,(destadr)+

 dbra d3,.xloop
 swap.w d4 ;restore hbits/ycnt
 sub.w #$100,d4
 bcc .yloop
 rts


;**** unpack linerep ****

unpack_linerep

;** get hmap/vmap **  !! hmap first now !!

 moveq.l #0,d3
;hmap
 bsr get1bit
 bcc.s .hh0

 moveq #15,d1
 move.b d1,d3
 bsr getstream
 eor.b inword,d3
 asl.b #3,d3
.hh0
 bsr get1bit
 bcc.s .hl0

 moveq #7,d1
 or.b d1,d3
 bsr getstream
 eor.b inword,d3
.hl0
 moveq #8,d0
 and.b d3,d0
 beq.s .hni
 eor.b #7,d3
.hni

;vmap
 ror.l #8,d3

 bsr get1bit
 bcc.s .vh0

 moveq #15,d1
 move.b d1,d3
 bsr getstream
 eor.b inword,d3
 asl.b #3,d3
.vh0
 bsr get1bit
 bcc.s .vl0

 moveq #7,d1
 or.b d1,d3
 bsr getstream
 eor.b inword,d3
.vl0
 moveq #8,d0
 and.b d3,d0
 beq.s .vni
 eor.b #7,d3
.vni


;(vbits in d3.l low, hbits in d3.l highest high byte)


;** unpack linerep body **

;** ROW 0 **
;use high byte of vbits for x byte count
 or.w #$300,d3
;preserve vbits on stack
 move.w d3,-(a7)

;get first pixel - naturally

 move.w colset(a6),d5
 bsr pixstream
.r0goteven_d0
 move.w d0,d2  ;stash first pixel
.r0goteven_d2

;how do i get second (odd) pixel?

;vbits say use left?
 add.b d3,d3
 bmi.s .r0left

;getbit say use left?
 getqbit
 bcs.s .r0str
.r0left
;use left!
 move.w d2,d0
 bra.s .r0leftjoin
.r0str
;use stream!
;d1:=left*2
 move.w d2,d1
 add.w d1,d1
 bsr mpixstream
.r0leftjoin

;got second pixel!

;now d0.w= second pixel
;so now merge and write byte
 asl.b #4,d2
 or.b d0,d2
 move.b d2,(destadr)+

;finished row 0 yet?
 sub.w #$100,d3
 bcs.s .done_row0

;get next even pixel into d2.w

;(d2.w presently equals previous byte)

;how to get even pixel?

;vbits say use left?
 add.b d3,d3
 bmi.s .r0eleft

;getbit say use left?
 getqbit
 bcs.s .r0estr
.r0eleft
;use left!
 and.b #$0f,d2
 bra.s .r0goteven_d2
.r0estr
;use stream!
;d1:=left*2
 moveq #$0f,d1
 and.w d2,d1
 add.w d1,d1
 bsr mpixstream
 bra.s .r0goteven_d0

;done first row!
.done_row0

;** ROWS 1..7 **

;vpref is high byte (first)
;ycnt is low byte (second)
 move.w #$0006,-(a7)

.ryloop

;hbits say whole row?

 add.l d3,d3
 bmi .dup_row

;retrieve vbits

 move.w 2(a7),d3 ;#$0300 xbytecnt in high byte
;;or.w #$300,d3

 clr.w inword

;how do i get first pixel?  ROWS 1..7

;(get up in d2.w)
 move.b -4(destadr),d2
 lsr.b #4,d2

;getbit say use up?
 getqbit
 bcc.s .1up
.1str
;use stream!
;d1:=up*2
 move.w d2,d1
 add.w d1,d1
 bsr mpixstream
.goteven_d0
 move.w d0,d2  ;stash even pixel
.1up
.goteven_d2

;got first/even pixel

;how do i get second/odd pixel?  ROWS 1..7

;vbits say use left?
 add.b d3,d3
 bmi.s .left

;which vpref-erence?
 tst.b (a7)
 bpl.s .prefleft

;* prefer up *
;get up
 moveq #$0f,d0
 and.b -4(destadr),d0

;getbit say use up?
 getqbit
 bcc.s .gotodd_d0

;left<>up? (can i use left?)
 cmp.b d2,d0
 beq.s .str_notup

;getbit say use left?
 getqbit
 bcs.s .str_notul

;set vpref false and use left
 clr.b (a7)
.left move.w d2,d0
 bra.s .gotodd_d0

;create tcols minus up
.str_notup
 add.b d0,d0
 move.w colset(a6),d5
 and.w bitmask(tabadr,d0.w),d5
 bsr pixstream
 ;now d0.w is odd pixel
 bra.s .gotodd_d0


;* prefer left *
.prefleft
;getbit say use left?
 getqbit
 bcs.s .not_left
;use left!
 move.w d2,d0
 bra.s .gotodd_d0
.not_left
;(get up)
 moveq #$0f,d0
 and.b -4(destadr),d0

;up<>left? (can i use up?)
 cmp.b d0,d2
 beq.s .str_notleft

;getbit say use up?
 getqbit
 bcc.s .nowuppref
.str_notul
;create tcols minus left AND up
 move.w colset(a6),d5
 add.b d0,d0
 move.w d2,d1
 add.b d1,d1
 and.w bitmask(tabadr,d0.w),d5
 and.w bitmask(tabadr,d1.w),d5
 bsr pixstream

;now d0.w is odd pixel
 bra.s .gotodd_d0

;set vpref true
.nowuppref
 st (a7)
 bra.s .gotodd_d0

;create tcols minus left
.str_notleft
 move.w d2,d1
 add.b d1,d1
 bsr mpixstream
;now d0.w is odd pixel
;;bra.s .gotodd_d0

;got second pixel!
.gotodd_d0
;now d0.w= second pixel
;merge and write byte
 asl.b #4,d2
 or.b d0,d2
 move.b d2,(destadr)+
;more bytes this row?
 sub.w #$100,d3
 bcs .rynext

;get next even pixel into d2.w ROWS 1..7

;(d2.w equals previous byte)

;how should we get even pixel then? ROWS 1..7

 and.b #$0f,d2
;vbits say use left?
 add.b d3,d3
 bmi .goteven_d2

;which vpref-erence?
 tst.b (a7)
 bpl.s .eprefleft

;* even prefers up *
;get up
;;moveq #0,d0
 move.b -4(destadr),d0
 lsr.b #4,d0

;getbit say use up?
 getqbit
 bcc .goteven_d0

;left<>up? (can i use left?)
 cmp.b d2,d0
 beq.s .estr_notup

;getbit say use left?
 getqbit
 bcs.s .estr_notul
 clr.b (a7)
 bra .goteven_d2

;create tcols minus up
.estr_notup
 add.b d0,d0
 move.w colset(a6),d5
 and.w bitmask(tabadr,d0.w),d5
 bsr pixstream
;now d0.w is even pixel
 bra .goteven_d0


;* even prefers left *
.eprefleft
;getbit say use left?
 getqbit
 bcc .goteven_d2

;(get up)
 move.b -4(destadr),d0
 lsr.b #4,d0

;up<>left? (can i use up?)
 cmp.b d0,d2
 beq.s .estr_notleft

;getbit say use up?
 getqbit
 bcc.s .enowuppref

.estr_notul
;create tcols minus left AND up
 move.w colset(a6),d5
 add.b d0,d0
 move.w d2,d1
 add.b d1,d1
 and.w bitmask(tabadr,d0.w),d5
 and.w bitmask(tabadr,d1.w),d5
 bsr pixstream

;now d0.w is even pixel
 bra .goteven_d0

;set vpref true
.enowuppref
 st (a7)
 bra .goteven_d0

;create tcols minus left
.estr_notleft
 move.w d2,d1
 add.b d1,d1
 bsr mpixstream
;now d0.w is even pixel
 bra .goteven_d0

;hbits says whole row
.dup_row
 move.l -4(destadr),(destadr)+
.rynext
 subq.b #$01,1(a7)
 bcc .ryloop

;pop off vpref/ycnt and vbits
 addq.l #4,a7
 rts





;**** mega unpacker main ****

mega_unpack
; sub.w #tables_size,sp
; move.l sp,a2
; movem.l a0-a1,-(sp)
; bsr build_tables
; movem.l (sp)+,a0-a1
; move.l sp,a2
; bsr.s mega_qunpack
; add.w #tables_size,sp
; rts

;mega_qunpack

;need sourceadr, destadr

 move.l a0,sourceadr
 move.l a1,destadr
 lea packer_data_space.w,a2



 move.l a2,tabadr
 lea 32+256+127(tabadr),rangeadr
 lea 32+256+511(tabadr),a0

;** initialise **

;sub.w #tables_size,a7
;move.l a7,a0

;allocate variable workspace
 link a6,#-var_bytes

;bsr build_tables


 moveq #0,inbits
 moveq #0,inword

;** read number of chars **

 moveq #8,d0
 bsr getbits
 move.w inword,d1
 moveq #2,d0
 bsr getbits
 asl.w #8,inword
 add.w inword,d1

;(d1=chnum)
 move.w d1,chnum(a6)

;** read colset_num **

;(d1=chnum)
 cmp.w #max_colsets,d1
 bls.s .10
 move.w #max_colsets,d1
.10
 bsr getbigstream

;** get colsets **

;{inword.w=colset_num-1}
 move.w inword,d3
 move.w d3,d4
;colset #0
 bra.s .0

;and the rest

.csloop
;delta or raw?
 bsr get1bit
 bcs.s .16

;delta colset

;get base colset
 move.w d4,d1
 sub.w d3,d1
 bsr getbigstream
 add.w inword,inword
 move.w (a7,inword.w),d2 ;base colset

;flip bit
 moveq #4,d0
 bsr getbits
 moveq #1,d1
 asl.w inword,d1
 eor.w d1,d2
 move.w d2,-(a7)
 bra.s .csnext

;raw colset
.16
.0 moveq #16,d0
 bsr getbits
 move.w inword,-(a7)
.csnext
 dbra d3,.csloop

;got colsets

;** unpack characters! **

 move.w #1,-(a7) ;colset_indx+1
 clr.w chi(a6)

chiloop

;* which colset? *

 move.w (a7),d1
 move.w d1,d3
 bsr getbigstream
 tst.w inword
 bne.s .no_csinc
 addq.w #1,(a7)
.no_csinc sub.w d3,inword
;inword = [0..colset_indx]-colset_indx-1 = [-colset_indx-1..-1]
 add.w inword,inword
 move.w colset_endofs(a6,inword.w),colset(a6)

;* which pack type? *

 bsr get1bit
 bcs.s .lr
 bsr unpack_sim
 bra.s .next
.lr
 bsr unpack_linerep
.next
done1
 addq.w #1,chi(a6)
 move.w chi(a6),d0
 cmp.w chnum(a6),d0
 bne.s chiloop

;done!
;(calc length)
 moveq #0,d1
 move.w chnum(a6),d1
 asl.l #5,d1

 unlk a6
;might need to pop off space for range tables
;;add.w #tables_size,a7
; add.w #tables_size,sp ;<< ** This needs a change!!
 rts



;**** tables ****

build_tables

;a2=adr of table buffer
 move.l a2,a0


;* bitmask(tabadr) *
 move.l a0,tabadr

 move.w #$fffe,d0

 moveq #15,d3
.100 move.w d0,(a0)+
 rol.w #1,d0
 dbra d3,.100

;* bitcount(tabadr) *

 moveq #0,d2
.200
 move.b d2,d0
 moveq #0,d1

.2 add.b d0,d0
 bcc.s .z
 addq.b #1,d1
.z bne.s .2

.gotcount
 move.b d1,(a0)+
 addq.b #1,d2
 bne.s .200

;* minbits(rangeadr) *

;;;lea 127(a0),rangeadr

;uurrghh - my head hurts

 moveq #1,d2 ;range

;minbits
.l2 move.b d2,d0

 moveq #7,d1
.u add.b d0,d0
 dbcs d1,.u

;d1=0..7
 move.b d1,(a0)+
 addq.b #1,d2
 bne.s .l2
;last byte
 move.b #8,(a0)+

;* addifhi(rangeadr) *

 moveq #2,d2 ;range
;addifhi

.aih2 move.b d2,d0

.aih1 subq.b #1,d0
 move.b d0,(a0)+
 bne.s .aih1
 add.b d2,d2
 bne.s .aih2
;last byte
 move.b #$ff,(a0)+

;     8,9,a,b,c,d,e,f,10
;  0,1,1,2,2,2,2,3,3,3,3,3,3,3,3,4
;  0,1,0,3,2,1,0,7,6,5,4,3,2,1,0,

;** make big pixstream index-to-colour table **
;00010110
;1,2,4... 9,10,16

 move.l a0,a1

 move.w #$ff,d3
.910
 moveq #8,d1
 sub.b bitcount(tabadr,d3.w),d1
 add.l d1,a1

 moveq #7,d1
 move.b d3,d0

.900 add.b d0,d0
 dbcc d1,.900
 bcs.s .901
 move.b d1,-(a1)
 dbra d1,.900
.901
 addq.l #8,a1
 dbf d3,.910

;done!

 rts
