	;;
	;; mount-and-boot - Mount persisted drive slots
	;;                  and boot.
	;;
	;; Author: Thomas Cherryhomes
	;;   <thom.cherryhomes@gmail.com>
	;;

	;; Zero Page

DSOFF	= 	$80 		; Device Slot table offset
HSOFF	=	$82		; Host Slot table offset
CURDS	=	$83		; Current Device slot
CURDSHS	=	$84		; Current Device Slot - Host Slot
CURDSM	=	$85		; Current Device Slot - Mode
	
       ; PAGE 3
       ; DEVICE CONTROL BLOCK (DCB)

DCB     =     $0300   ; BASE
DDEVIC  =     DCB     ; DEVICE #
DUNIT   =     DCB+1   ; UNIT #
DCOMND  =     DCB+2   ; COMMAND
DSTATS  =     DCB+3   ; STATUS/DIR
DBUFL   =     DCB+4   ; BUF ADR L
DBUFH   =     DCB+5   ; BUF ADR H
DTIMLO  =     DCB+6   ; TIMEOUT (S)
DRSVD   =     DCB+7   ; NOT USED
DBYTL   =     DCB+8   ; BUF LEN L
DBYTH   =     DCB+9   ; BUF LEN H
DAUXL   =     DCB+10  ; AUX BYTE L
DAUXH   =     DCB+11  ; AUX BYTE H

HATABS  =     $031A   ; HANDLER TBL

       ; IOCB'S * 8

IOCB    =     $0340   ; IOCB BASE
ICHID   =     IOCB    ; ID
ICDNO   =     IOCB+1  ; UNIT #
ICCOM   =     IOCB+2  ; COMMAND
ICSTA   =     IOCB+3  ; STATUS
ICBAL   =     IOCB+4  ; BUF ADR LOW
ICBAH   =     IOCB+5  ; BUF ADR HIGH
ICPTL   =     IOCB+6  ; PUT ADDR L
ICPTH   =     IOCB+7  ; PUT ADDR H
ICBLL   =     IOCB+8  ; BUF LEN LOW
ICBLH   =     IOCB+9  ; BUF LEN HIGH
ICAX1   =     IOCB+10 ; AUX 1
ICAX2   =     IOCB+11 ; AUX 2
ICAX3   =     IOCB+12 ; AUX 3
ICAX4   =     IOCB+13 ; AUX 4
ICAX5   =     IOCB+14 ; AUX 5
ICAX6   =     IOCB+15 ; AUX 6

       ; OS ROM VECTORS

CIOV    =     $E456   ; CIO ENTRY
SIOV    =     $E459   ; SIO ENTRY
COLDST	=     $E477   ; COLD START
	
       ; CONSTANTS

GETREC	=	$05   ; CIO GET RECORD
PUTREC  =	$09   ; CIO PUTREC
PUTCHR	=	$0B   ; CIO PUTCHR

	;; Number of sectors to load

SECLEN	=	(END-HDR)/128

	;; DeviceSlots/HostSlots lengths in bytes
	
DSLEN	=	256
HSLEN	=	304

	;; Entry sizes in bytes
DSENT	=	38
HSENT	=	32
	
	;; Code begin
	
	ORG	$06F0		; $0700 MEMLO - 16 byte ATR paragraph.
	OPT	h-		; No executable header, we provide our own.

ATR:
	.BYTE $96,$02,$80,$16,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Hack
HDR:
	.BYTE $00,SECLEN,$00,$70,$C0,$E4

START:
	;; Read Host slots
	
	LDA	#<RHSTBL
	LDY	#>RHSTBL
	JSR	DOSIOV

	;; Read Device Slots

	LDA	#<RDSTBL
	LDY	#>RDSTBL
	JSR	DOSIOV

	;;  Set table offsets for each
	LDA	#<HS
	STA	HSOFF
	LDA	#>HS
	STA	HSOFF+1
	LDA	#<DS
	STA	DSOFF
	LDA	#>DS
	STA	DSOFF+1

	;; X = Device slot index
	;; Y = Offset in table (for host slot and mode)
	
	;; Is device slot occupied? (is there a host slot that isn't $FF?)
	LDY	#$00		; Start at 0
	LDX	#$00		; Start at 0 (Device slot 1)
GHS:	LDA	(DSOFF),Y	; Get Host slot (first byte of table)
	CMP	#$FF		; Is it an empty host slot?
	BEQ	NXTDS		; Yes, go to next device slot.

	;; Attempt to mount host.
	STA	MHS		; Store in mount host slot table
	LDA	#<MHSTBL	; Mount Host Slot table
	LDY	#>MHSTBL	; ...
	JSR	DOSIOV		; Do it.

	;; Attempt to mount device slot
	STX	MDSS		; Store Device Slot into mount device slot DCB table
	LDY	#$01		; mode is offset 1 in retrieved device slot table
	LDA	(DSOFF),Y	; Get mode
	STA	MDSM		; Store in mode portion of DCB table
	LDA	#<MDSTBL	; Mount Device Slot DCB table
	LDY	#>MDSTBL	; ...
	JSR	DOSIOV

	;; Go to next device slot
NXTDS:	CPX	#$08	        ; Are we at end?
	BEQ	DONE		; We're done.
	CLC			; Otherwise, Clear carry
	LDA	DSOFF		; Low byte of device slot table offset
	ADC	#DSENT		; Add 38.
	STA	DSOFF		; And store
	LDA	DSOFF+1		; High byte of device slot table offset
	ADC	#00		; ...
	STA	DSOFF+1		; Write back out with carry.
	INX			; Next host slot index.
	JMP	GHS		; Get next host slot.
	
DONE:	JMP	COLDST		; Cold boot.

;;; COPY TABLE TO DCB AND DO SIO CALL ;;;;;;;;;;;

DOSIOV: STA	DODCBL+1	; Set source address
	STY	DODCBL+2
	LDY	#$0C		; 12 bytes
DODCBL	LDA	$FFFF,Y		; Changed above.
	STA	DCB,Y		; To DCB table
	DEY			; Count down
	BPL	DODCBL		; Until done

SIOVDST:	
	JSR	SIOV		; Call SIOV
	LDY	DSTATS		; Get STATUS in Y
	TYA			; Copy it into A	
	RTS			; Done

;;; DCB table for Read Host Slots

RHSTBL:
	.BYTE $70		; DDEVIC = $70 (Fuji)
	.BYTE $01		; DUNIT = 1
	.BYTE $F4		; DCOMND = Read host Slots
	.BYTE $40		; DSTATS = Read
	.WORD HS		; DBUF = Put buffer at end of memory
	.BYTE $0F		; DTIMLO = 15 seconds.
	.BYTE $00		; DRESVD = $00
	.WORD HSLEN		; DBYT
	.WORD $00		; DAUX = 0
	
;;; DCB table for Read Device Slots

RDSTBL:
	.BYTE $70		; DDEVIC = $70 (Fuji)
	.BYTE $01		; DUNIT = 1
	.BYTE $F2		; DCOMND = Read Device Slots
	.BYTE $40		; DSTATS = Read
	.WORD DS		; DBUF = Put buffer at end of memory
	.BYTE $0F		; DTIMLO = 15 seconds.
	.BYTE $00		; DRESVD = $00
	.WORD DSLEN		; DBYT
	.WORD $00		; DAUX = 0

;;; DCB table for Mount Host Slot

MHSTBL:
	.BYTE $70		; DDEVIC = $70 (Fuji)
	.BYTE $01		; DUNIT = 1
	.BYTE $F9		; DCOMND = mount host slot
	.BYTE $00		; DSTATS = no payload
	.WORD 0000		; DBUF = Put buffer at end of memory
	.BYTE $0F		; DTIMLO = 15 seconds.
	.BYTE $00		; DRESVD = $00
	.WORD 0			; DBYT
MHS:	.byte $FF		; DAUX1 = host slot
	
;;; DCB table for Mount Device Slot

MDSTBL:
	.BYTE $70		; DDEVIC = $70 (Fuji)
	.BYTE $01		; DUNIT = 1
	.BYTE $F8		; DCOMND = mount device slot
	.BYTE $40		; DSTATS = no payload
	.WORD 0000		; DBUF = no buffer
	.BYTE $0F		; DTIMLO = 15 seconds.
	.BYTE $00		; DRESVD = $00
	.WORD 0			; DBYT = no payload
MDSS:	.BYTE $FF		; DAUX1 = Host slot # (0-7)
MDSM:	.BYTE $FF		; DAUX2 = Mode.
	
	.BYTE	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; For padding calc below.
	
	.ALIGN	$80,$00		; 128 byte align for sectors.

END:	
	.PRINT "HDR: ",HDR
	.PRINT "END: ",END
	.PRINT "Number of Sectors: ",SECLEN

HS:	.DS	256		; Hostslot data
DS:	.DS	304		; DeviceSlot data
