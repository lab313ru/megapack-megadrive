.align  2
.globl init_mega
.type init_mega, @function
init_mega:
                movea.l #0xFFD4CA,%a0
                movea.l %a0,%a2
                move.w  #0xFFFE,%d0
                moveq   #0xF,%d3

loc_C5C8:
                move.w  %d0,(%a0)+
                rol.w   #1,%d0
                dbf     %d3,loc_C5C8
                moveq   #0,%d2

loc_C5D2:
                move.b  %d2,%d0
                moveq   #0,%d1

loc_C5D6:
                add.b   %d0,%d0
                bcc.s   loc_C5DC
                addq.b  #1,%d1

loc_C5DC:
                bne.s   loc_C5D6
                move.b  %d1,(%a0)+
                addq.b  #1,%d2
                bne.s   loc_C5D2
                moveq   #1,%d2

loc_C5E6:
                move.b  %d2,%d0
                moveq   #7,%d1

loc_C5EA:
                add.b   %d0,%d0
                dbcs    %d1,loc_C5EA
                move.b  %d1,(%a0)+
                addq.b  #1,%d2
                bne.s   loc_C5E6
                move.b  #8,(%a0)+
                moveq   #2,%d2

loc_C5FC:
                move.b  %d2,%d0

loc_C5FE:
                subq.b  #1,%d0
                move.b  %d0,(%a0)+
                bne.s   loc_C5FE
                add.b   %d2,%d2
                bne.s   loc_C5FC
                move.b  #0xFF,(%a0)+
                movea.l %a0,%a1
                move.w  #0xFF,%d3

loc_C612:
                moveq   #8,%d1
                sub.b   0x20(%a2,%d3.w),%d1
                adda.l  %d1,%a1
                moveq   #7,%d1
                move.b  %d3,%d0

loc_C61E:
                add.b   %d0,%d0
                dbcc    %d1,loc_C61E
                bcs.s   loc_C62C
                move.b  %d1,-(%a1)
                dbf     %d1,loc_C61E

loc_C62C:
                addq.l  #8,%a1
                dbf     %d3,loc_C612
                rts
.size   init_mega, .-init_mega
/*; End of function init_mega*/

.align  2
sub_C2B0:
                moveq   #0,%d3
                bsr.w   sub_C0A8
                bcc.s   loc_C2C4
                moveq   #0xF,%d1
                move.b  %d1,%d3
                bsr.w   sub_C0FE
                eor.b   %d7,%d3
                asl.b   #3,%d3

loc_C2C4:
                bsr.w   sub_C0A8
                bcc.s   loc_C2D4
                moveq   #7,%d1
                or.b    %d1,%d3
                bsr.w   sub_C0FE
                eor.b   %d7,%d3

loc_C2D4:
                moveq   #8,%d0
                and.b   %d3,%d0
                beq.s   loc_C2DE
                eori.b  #7,%d3

loc_C2DE:
                ror.l   #8,%d3
                bsr.w   sub_C0A8
                bcc.s   loc_C2F2
                moveq   #0xF,%d1
                move.b  %d1,%d3
                bsr.w   sub_C0FE
                eor.b   %d7,%d3
                asl.b   #3,%d3

loc_C2F2:
                bsr.w   sub_C0A8
                bcc.s   loc_C302
                moveq   #7,%d1
                or.b    %d1,%d3
                bsr.w   sub_C0FE
                eor.b   %d7,%d3

loc_C302:
                moveq   #8,%d0
                and.b   %d3,%d0
                beq.s   loc_C30C
                eori.b  #7,%d3

loc_C30C:
                ori.w   #0x300,%d3
                move.w  %d3,-(%sp)
                move.w  -6(%a6),%d5
                bsr.w   sub_C134

loc_C31A:
                move.w  %d0,%d2

loc_C31C:
                add.b   %d3,%d3
                bmi.s   loc_C330
                clr.w   %d7
                subq.b  #1,%d6
                bcc.s   loc_C32C
                move.w  (%a5)+,%d7
                swap    %d7
                moveq   #0xF,%d6

loc_C32C:
                add.l   %d7,%d7
                bcs.s   loc_C334

loc_C330:
                move.w  %d2,%d0
                bra.s   loc_C33C

loc_C334:
                move.w  %d2,%d1
                add.w   %d1,%d1
                bsr.w   sub_C12C

loc_C33C:
                asl.b   #4,%d2
                or.b    %d0,%d2
                move.b  %d2,(%a4)+
                subi.w  #0x100,%d3
                bcs.s   loc_C36E
                add.b   %d3,%d3
                bmi.s   loc_C35C
                clr.w   %d7
                subq.b  #1,%d6
                bcc.s   loc_C358
                move.w  (%a5)+,%d7
                swap    %d7
                moveq   #0xF,%d6

loc_C358:
                add.l   %d7,%d7
                bcs.s   loc_C362

loc_C35C:
                andi.b  #0xF,%d2
                bra.s   loc_C31C

loc_C362:
                moveq   #0xF,%d1
                and.w   %d2,%d1
                add.w   %d1,%d1
                bsr.w   sub_C12C
                bra.s   loc_C31A

loc_C36E:
                move.w  #6,-(%sp)

loc_C372:
                add.l   %d3,%d3
                bmi.w   loc_C4F0
                move.w  2(%sp),%d3
                clr.w   %d7
                move.b  -4(%a4),%d2
                lsr.b   #4,%d2
                clr.w   %d7
                subq.b  #1,%d6
                bcc.s   loc_C390
                move.w  (%a5)+,%d7
                swap    %d7
                moveq   #0xF,%d6

loc_C390:
                add.l   %d7,%d7
                bcc.s   loc_C39E
                move.w  %d2,%d1
                add.w   %d1,%d1
                bsr.w   sub_C12C

loc_C39C:
                move.w  %d0,%d2

loc_C39E:
                add.b   %d3,%d3
                bmi.s   loc_C3D2
                tst.b   (%sp)
                bpl.s   loc_C3E6
                moveq   #0xF,%d0
                and.b   -4(%a4),%d0
                clr.w   %d7
                subq.b  #1,%d6
                bcc.s   loc_C3B8
                move.w  (%a5)+,%d7
                swap    %d7
                moveq   #0xF,%d6

loc_C3B8:
                add.l   %d7,%d7
                bcc.s   loc_C438
                cmp.b   %d2,%d0
                beq.s   loc_C3D6
                clr.w   %d7
                subq.b  #1,%d6
                bcc.s   loc_C3CC
                move.w  (%a5)+,%d7
                swap    %d7
                moveq   #0xF,%d6

loc_C3CC:
                add.l   %d7,%d7
                bcs.s   loc_C414
                clr.b   (%sp)

loc_C3D2:
                move.w  %d2,%d0
                bra.s   loc_C438

loc_C3D6:
                add.b   %d0,%d0
                move.w  -6(%a6),%d5
                and.w   (%a2,%d0.w),%d5
                bsr.w   sub_C134
                bra.s   loc_C438

loc_C3E6:
                clr.w   %d7
                subq.b  #1,%d6
                bcc.s   loc_C3F2
                move.w  (%a5)+,%d7
                swap    %d7
                moveq   #0xF,%d6

loc_C3F2:
                add.l   %d7,%d7
                bcs.s   loc_C3FA
                move.w  %d2,%d0
                bra.s   loc_C438

loc_C3FA:
                moveq   #0xF,%d0
                and.b   -4(%a4),%d0
                cmp.b   %d0,%d2
                beq.s   loc_C430
                clr.w   %d7
                subq.b  #1,%d6
                bcc.s   loc_C410
                move.w  (%a5)+,%d7
                swap    %d7
                moveq   #0xF,%d6

loc_C410:
                add.l   %d7,%d7
                bcc.s   loc_C42C

loc_C414:
                move.w  -6(%a6),%d5
                add.b   %d0,%d0
                move.w  %d2,%d1
                add.b   %d1,%d1
                and.w   (%a2,%d0.w),%d5
                and.w   (%a2,%d1.w),%d5
                bsr.w   sub_C134
                bra.s   loc_C438

loc_C42C:
                st      (%sp)
                bra.s   loc_C438

loc_C430:
                move.w  %d2,%d1
                add.b   %d1,%d1
                bsr.w   sub_C12C

loc_C438:
                asl.b   #4,%d2
                or.b    %d0,%d2
                move.b  %d2,(%a4)+
                subi.w  #0x100,%d3
                bcs.w   loc_C4F4
                andi.b  #0xF,%d2
                add.b   %d3,%d3
                bmi.w   loc_C39E
                tst.b   (%sp)
                bpl.s   loc_C498
                move.b  -4(%a4),%d0
                lsr.b   #4,%d0
                clr.w   %d7
                subq.b  #1,%d6
                bcc.s   loc_C466
                move.w  (%a5)+,%d7
                swap    %d7
                moveq   #0xF,%d6

loc_C466:
                add.l   %d7,%d7
                bcc.w   loc_C39C
                cmp.b   %d2,%d0
                beq.s   loc_C486
                clr.w   %d7
                subq.b  #1,%d6
                bcc.s   loc_C47C
                move.w  (%a5)+,%d7
                swap    %d7
                moveq   #0xF,%d6

loc_C47C:
                add.l   %d7,%d7
                bcs.s   loc_C4C4
                clr.b   (%sp)
                bra.w   loc_C39E

loc_C486:
                add.b   %d0,%d0
                move.w  -6(%a6),%d5
                and.w   (%a2,%d0.w),%d5
                bsr.w   sub_C134
                bra.w   loc_C39C

loc_C498:
                clr.w   %d7
                subq.b  #1,%d6
                bcc.s   loc_C4A4
                move.w  (%a5)+,%d7
                swap    %d7
                moveq   #0xF,%d6

loc_C4A4:
                add.l   %d7,%d7
                bcc.w   loc_C39E
                move.b  -4(%a4),%d0
                lsr.b   #4,%d0
                cmp.b   %d0,%d2
                beq.s   loc_C4E4
                clr.w   %d7
                subq.b  #1,%d6
                bcc.s   loc_C4C0
                move.w  (%a5)+,%d7
                swap    %d7
                moveq   #0xF,%d6

loc_C4C0:
                add.l   %d7,%d7
                bcc.s   loc_C4DE

loc_C4C4:
                move.w  -6(%a6),%d5
                add.b   %d0,%d0
                move.w  %d2,%d1
                add.b   %d1,%d1
                and.w   (%a2,%d0.w),%d5
                and.w   (%a2,%d1.w),%d5
                bsr.w   sub_C134
                bra.w   loc_C39C

loc_C4DE:
                st      (%sp)
                bra.w   loc_C39C

loc_C4E4:
                move.w  %d2,%d1
                add.b   %d1,%d1
                bsr.w   sub_C12C
                bra.w   loc_C39C

loc_C4F0:
                move.l  -4(%a4),(%a4)+

loc_C4F4:
                subq.b  #1,1(%sp)
                bcc.w   loc_C372
                addq.l  #4,%sp
                rts
/*; End of function sub_C2B0*/

.align  2
sub_C12C:
                move.w  -6(%a6),%d5
                and.w   (%a2,%d1.w),%d5
/*; End of function sub_C12C*/


sub_C134:
                clr.w   %d4
                move.b  %d5,%d4
                move.b  0x20(%a2,%d4.w),%d4
                move.w  %d4,-(%sp)
                move.w  %d5,%d0
                lsr.w   #8,%d0
                add.b   0x20(%a2,%d0.w),%d4
                move.b  -0x80(%a3,%d4.w),%d0
                sub.b   %d0,%d6
                bcc.s   loc_C15E
                add.b   %d0,%d6
                move.w  (%a5)+,%d7
                swap    %d7
                rol.w   %d6,%d7
                sub.b   %d6,%d0
                moveq   #0x10,%d6
                sub.b   %d0,%d6
                bra.s   loc_C160

loc_C15E:
                clr.w   %d7

loc_C160:
                rol.l   %d0,%d7
                cmp.b   0x7F(%a3,%d4.w),%d7
                bls.s   loc_C17C
                subq.b  #1,%d6
                bcc.s   loc_C174
                swap    %d7
                move.w  (%a5)+,%d7
                swap    %d7
                moveq   #0xF,%d6

loc_C174:
                rol.l   #1,%d7
                sub.b   0x7F(%a3,%d4.w),%d7
                subq.w  #1,%d7

loc_C17C:
                move.w  %d7,%d0
                sub.w   (%sp)+,%d0
                bcc.s   loc_C192
                andi.w  #0xFF,%d5
                asl.w   #3,%d5
                add.w   %d7,%d5
                moveq   #0,%d0
                move.b  (%a0,%d5.w),%d0
                rts

loc_C192:
                clr.b   %d5
                lsr.w   #5,%d5
                add.w   %d0,%d5
                moveq   #8,%d0
                add.b   (%a0,%d5.w),%d0
                rts
/*; End of function sub_C134*/

.align  2
sub_C1A0:
                move.w  -4(%a6),%d1
                bsr.w   sub_C0F8
                not.w   %d7
                asl.w   #5,%d7
                lea     (%a4,%d7.w),%a1
                clr.w   %d3
                bsr.w   sub_C0A8
                bcc.s   loc_C1C4
                moveq   #0xF,%d1
                bsr.w   sub_C0FE
                not.b   %d7
                asl.w   #4,%d7
                move.b  %d7,%d3

loc_C1C4:
                bsr.w   sub_C0A8
                bcc.s   loc_C1D4
                moveq   #0xF,%d1
                or.b    %d1,%d3
                bsr.w   sub_C0FE
                eor.b   %d7,%d3

loc_C1D4:
                move.b  %d3,-8(%a6)
                clr.w   %d4
                bsr.w   sub_C0A8
                bcc.s   loc_C1EC
                moveq   #0xF,%d1
                bsr.w   sub_C0FE
                not.b   %d7
                asl.w   #4,%d7
                move.b  %d7,%d4

loc_C1EC:
                bsr.w   sub_C0A8
                bcc.s   loc_C1FC
                moveq   #0xF,%d1
                or.b    %d1,%d4
                bsr.w   sub_C0FE
                eor.b   %d7,%d4

loc_C1FC:
                ori.w   #0x700,%d4

loc_C200:
                add.b   %d4,%d4
                bcs.s   loc_C26C
                clr.w   %d7
                move.b  -8(%a6),%d2
                moveq   #0xFFFFFFFE,%d0
                cmp.b   %d0,%d4
                beq.s   loc_C230
                moveq   #7,%d1

loc_C212:
                rol.b   #1,%d2
                bcs.s   loc_C22C
                cmp.b   %d0,%d2
                beq.s   loc_C22C
                clr.w   %d7
                subq.b  #1,%d6
                bcc.s   loc_C226
                move.w  (%a5)+,%d7
                swap    %d7
                moveq   #0xF,%d6

loc_C226:
                add.l   %d7,%d7
                bcc.s   loc_C22C
                addq.b  #1,%d2

loc_C22C:
                dbf     %d1,loc_C212

loc_C230:
                swap    %d4
                moveq   #3,%d3

loc_C234:
                add.b   %d2,%d2
                bcs.s   loc_C278
                move.w  #0xF0,%d1
                and.b   (%a1),%d1
                lsr.w   #3,%d1
                bsr.w   sub_C12C
                asl.b   #4,%d0
                moveq   #0xF,%d1
                and.b   (%a1)+,%d1
                add.b   %d2,%d2
                bcs.s   loc_C28A
                move.w  %d0,%d5
                swap    %d5
                add.w   %d1,%d1
                bsr.w   sub_C12C
                swap    %d5
                or.w    %d0,%d5
                move.b  %d5,(%a4)+
                dbf     %d3,loc_C234
                swap    %d4
                subi.w  #0x100,%d4
                bcc.s   loc_C200
                rts

loc_C26C:
                addq.b  #1,%d4
                move.l  (%a1)+,(%a4)+
                subi.w  #0x100,%d4
                bcc.s   loc_C200
                rts

loc_C278:
                add.b   %d2,%d2
                bcs.s   loc_C29E
                moveq   #0xF,%d1
                and.b   (%a1),%d1
                add.w   %d1,%d1
                bsr.w   sub_C12C
                moveq   #0xFFFFFFF0,%d1
                and.b   (%a1)+,%d1

loc_C28A:
                or.b    %d1,%d0
                move.b  %d0,(%a4)+
                dbf     %d3,loc_C234
                swap    %d4
                subi.w  #0x100,%d4
                bcc.w   loc_C200
                rts

loc_C29E:
                move.b  (%a1)+,(%a4)+
                dbf     %d3,loc_C234
                swap    %d4
                subi.w  #0x100,%d4
                bcc.w   loc_C200
                rts
/*; End of function sub_C1A0*/

.align  2
sub_C0A8:
	subq.b  #1,%d6
	bcs.s   loc_C0B2
	clr.w   %d7
	add.l   %d7,%d7
	rts
loc_C0B2:
	move.w  (%a5)+,%d7
	swap    %d7
	moveq   #0xF,%d6
	add.l   %d7,%d7
	rts

.align  2
sub_C0BC:
	sub.b   %d0,%d6
	bcs.s   loc_C0C6
	clr.w   %d7
	rol.l   %d0,%d7
	rts

loc_C0C6:
	add.b   %d0,%d6
	move.w  (%a5)+,%d7
	swap    %d7
	rol.w   %d6,%d7
	sub.b   %d6,%d0
	rol.l   %d0,%d7
	moveq   #0x10,%d6
	sub.b   %d0,%d6
	rts
/*; End of function sub_C0BC*/

/*; START OF FUNCTION CHUNK FOR sub_C0F8*/

loc_C0D8:
	subq.w  #1,%d1
	moveq   #0,%d2
	move.b  %d1,%d2
	addq.w  #1,%d2
	lsr.w   #8,%d1
	addq.w  #1,%d1
	bsr.s   sub_C0FE
	move.w  %d2,%d1
	subq.w  #1,%d7
	bcs.s   sub_C0FE
	asl.w   #8,%d7
	add.w   %d7,%d2
	moveq   #8,%d0
	bsr.s   sub_C0BC
	add.w   %d2,%d7
	rts
/*; END OF FUNCTION CHUNK FOR sub_C0F8*/


.align  2
sub_C0F8:

/*; FUNCTION CHUNK AT 0000C0D8 SIZE 00000020 BYTES*/

	cmp.w   #0x100,%d1
	bhi.s   loc_C0D8
/*; End of function sub_C0F8*/


.align  2
sub_C0FE:
	move.b  -0x80(%a3,%d1.w),%d0
	bsr.s   sub_C0BC
	cmp.b   0x7F(%a3,%d1.w),%d7
	bhi.s   loc_C10C
	rts

loc_C10C:
	subq.b  #1,%d6
	bcs.s   loc_C11A
	rol.l   #1,%d7
	sub.b   0x7F(%a3,%d1.w),%d7
	subq.w  #1,%d7
	rts

loc_C11A:
	swap    %d7
	move.w  (%a5)+,%d7
	add.l   %d7,%d7
	swap    %d7
	moveq   #0xF,%d6
	sub.b   0x7F(%a3,%d1.w),%d7
	subq.w  #1,%d7
	rts
/*; End of function sub_C0FE*/

/*; %a0 - src*/
/*; %a1 - dst*/

.align  2
.globl megaunp
.type megaunp, @function
megaunp:
	movea.l %a0,%a5
	movea.l %a1,%a4
	movea.l #0xFFD4CA,%a2
	movea.l %a2,%a2
	lea     0x19F(%a2),%a3
	lea     0x31F(%a2),%a0
	link    %a6,#-8
	moveq   #0,%d6
	moveq   #0,%d7
	moveq   #8,%d0
	bsr.w   sub_C0BC
	move.w  %d7,%d1
	moveq   #2,%d0
	bsr.w   sub_C0BC
	asl.w   #8,%d7
	add.w   %d7,%d1
	move.w  %d1,-2(%a6)
	cmp.w   #0x200,%d1
	bls.s   loc_C53A
	move.w  #0x200,%d1

loc_C53A:
	bsr.w   sub_C0F8
	move.w  %d7,%d3
	move.w  %d3,%d4
	bra.s   loc_C568

loc_C544:
	bsr.w   sub_C0A8
	bcs.s   loc_C568
	move.w  %d4,%d1
	sub.w   %d3,%d1
	bsr.w   sub_C0F8
	add.w   %d7,%d7
	move.w  (%sp,%d7.w),%d2
	moveq   #4,%d0
	bsr.w   sub_C0BC
	moveq   #1,%d1
	asl.w   %d7,%d1
	eor.w   %d1,%d2
	move.w  %d2,-(%sp)
	bra.s   loc_C570

loc_C568:
	moveq   #0x10,%d0
	bsr.w   sub_C0BC
	move.w  %d7,-(%sp)

loc_C570:
	dbf     %d3,loc_C544
	move.w  #1,-(%sp)
	clr.w   -4(%a6)

loc_C57C:
	move.w  (%sp),%d1
	move.w  %d1,%d3
	bsr.w   sub_C0F8
	tst.w   %d7
	bne.s   loc_C58A
	addq.w  #1,(%sp)

loc_C58A:
	sub.w   %d3,%d7
	add.w   %d7,%d7
	move.w  -8(%a6,%d7.w),-6(%a6)
	bsr.w   sub_C0A8
	bcs.s   loc_C5A0
	bsr.w   sub_C1A0
	bra.s   loc_C5A4

loc_C5A0:
	bsr.w   sub_C2B0

loc_C5A4:
	addq.w  #1,-4(%a6)
	move.w  -4(%a6),%d0
	cmp.w   -2(%a6),%d0
	bne.s   loc_C57C
	moveq   #0,%d1
	move.w  -2(%a6),%d1
	asl.l   #5,%d1
	unlk    %a6
	rts
.size   megaunp, .-megaunp
/*; End of function megaunp*/
