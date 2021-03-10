	;;
	;; mount-and-boot - Mount persisted drive slots
	;;                  and boot.
	;;
	;; Author: Thomas Cherryhomes
	;;   <thom.cherryhomes@gmail.com>
	;;

	;; Zero Page

RTCLOK0	=	$12
RTCLOK1 =	$13
RTCLOK2 =	$14
	
MSGL	= 	$80 		; MSG LO
MSGH	= 	$81		; MSG HI
SEL     =       $82		; Is select pressed? ($FF=yes)
WFST    =       $83            	; WIFI Status (3=connected)
WFTO	=	$84		; WIFI timeout counter (40 max)
COLOR2	=	$02C6		; Background color (Mode 2)
	
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

	;; Hardware Registers
CONSOL	=	$D01F		; Console switches
	
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
	.BYTE $00,SECLEN,$00,$07,$C0,$E4

START:
	;; Display Boot message
	
	LDA	#<BOOT1
	STA	MSGL
	LDA	#>BOOT1
	STA	MSGH
	JSR	DISPMSG

	;; Wait for WIFI

	JSR	WTWF
	
	;; Display Mount All msg

	LDA	#<BOOTMT
	STA	MSGL
	LDA	#>BOOTMT
	STA	MSGH
	JSR	DISPMSG
	
	;; Send mount all command to #FujiNet
	LDA	#<MATBL
	LDY	#>MATBL
	JSR	DOSIOV

	;; Check if ok, and change screen color if not.
	LDA	DSTATS		; Get status of mount all
	BPL	GDBOOT		; > 128 = ERROR

	;; Boot was bad.
	
MTERR:	LDA	#$44		; Error, change screen to red
	STA	COLOR2
	LDA	#<BOOTNO	; and display boot failed.
	STA	MSGL
	LDA	#>BOOTNO
	STA	MSGH
	JSR	DISPMSG

	;; Issue boot mode change to config.
	LDA	#<BMTBL		; Point to set boot mode table
	LDY	#>BMTBL
	JSR	DOSIOV		; Issue command.
	JMP	GOCOLD		; Go cold.

	;; Otherwise, Boot was good.
	
GDBOOT:	LDA	#<BOOTOK
	STA	MSGL
	LDA	#>BOOTOK
	STA	MSGH
	JSR	DISPMSG

	;; Count down, while checking for select.
	
GOCOLD: JSR	RTCLR		; Clear RTCLOK
CLLP:	LDA	CONSOL		; Check console switches
	CMP	#$05
	BNE	CLLP2		; Continue with loop

	;; SELECT pressed, display message, set boot config mode, go cold.

SELPR:	LDA	SEL		; Check select
	BMI	CLLP2		; If already pressed, we continue loop
	LDA	#$B4		; Select just pressed, turn Green
	STA	COLOR2		; Background
	LDA	#<BOOTSL	; Set up select pressed msg
	STA	MSGL		
	LDA	#>BOOTSL
	STA	MSGH
	JSR	DISPMSG		; Display it
	LDA	#$FF		; Indicate we've displayed msg
	STA	SEL		; so it's not displayed again.
	
	LDA	#<BMTBL		; set up set boot mode command
	LDY	#>BMTBL
	JSR	DOSIOV

	;; Otherwise continue on loop.
	
CLLP2:	LDX	RTCLOK2		; Read hi byte of clock
	CPX	#$FE		; Done?
	BCS	BYE		; Yup, bye
	BCC	CLLP		; Nope
BYE:	JMP	COLDST		; Cold boot.

;;; Clear RTCLOK
RTCLR:	LDA	#$00		; Clear clock
	STA	RTCLOK0
	STA	RTCLOK1
	STA	RTCLOK2
	RTS
	
;;; Wait for WIFI

	;; Display waiting msg
	
WTWF:	LDA	#$00
	STA	WFTO		; Clear WIFI timeout counter.
	LDA	#<BOOTWF
	STA	MSGL
	LDA	#>BOOTWF
	STA	MSGH
	JSR	DISPMSG
	JSR	RTCLR		; Clear RTCLOK
	
	;; Go ahead and check for consol, and bypass if needed

	LDA	CONSOL
	CMP	#$05
	BEQ	SELPR

	;; Finally, get the wifi status.
	
GETWF:	LDA	#<WFTBL
	LDY	#>WFTBL
	JSR	DOSIOV
	LDA	WFST
	ASL
	ASL
	ASL
	ASL
	STA	COLOR2
	CMP	#$30		; Connected?
	BEQ	WFDNE
	CMP	#$60		; Not connected yet?
	BEQ	WFWAI		; if so, wait.
WFBAD:	JMP	MTERR		; Display bad and go to config
WFWAI:	LDA	CONSOL		; Check console switches again
	CMP	#$05		; SELECT?
	BEQ	SELPR		; Yes, go to select pressed.
	LDA	RTCLOK2		; Check clock
	AND	#$3F		; check after 64 ticks.
	BNE	WFWAI		; Not yet, continue waiting.
	LDA	WFTO		; Check Timeout counter
	CMP	#$20		; 32 tries?
	BEQ	WFBAD		; Yes, bad, go to config
	INC	WFTO		; Otherwise increment timeout timer
	BEQ	GETWF		; And continue waiting.	
WFDNE:	RTS
	
;;; Display Message via E:
	
DISPMSG:
	LDX	#$00		; E: (IOCB #0)
	LDA	#PUTREC		; PUT Record
	STA	ICCOM,X		
	LDA	MSGL
	STA	ICBAL,X
	LDA	MSGH
	STA	ICBAH,X
	LDA	#$7F		; 128 bytes max
	STA	ICBLL,X
	LDA	#$00
	STA	ICBLH,X
	JSR	CIOV
	RTS
	
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

;;; DCB table for wifi status

WFTBL:
	.BYTE $70		; DDEVIC = $70 (Fuji)
	.BYTE $01		; DUNIT = 1
	.BYTE $FA		; DCOMND = Get WIFI status
	.BYTE $40		; DSTATS = -> ATARI
	.WORD WFST 		; DBUF = WFST
	.BYTE $0F		; DTIMLO = 15 seconds.
	.BYTE $00		; DRESVD = $00
	.WORD 1			; one byte
	.WORD $00		; DAUX = 0	
	
;;; DCB table for set boot mode

BMTBL:
	.BYTE $70		; DDEVIC = $70 (Fuji)
	.BYTE $01		; DUNIT = 1
	.BYTE $D6		; DCOMND = Mount all
	.BYTE $00		; DSTATS = None
	.WORD 0 		; DBUF = Put buffer at end of memory
	.BYTE $0F		; DTIMLO = 15 seconds.
	.BYTE $00		; DRESVD = $00
	.WORD 0			; DBYT
	.WORD $00		; DAUX = 0 = Boot into CONFIG	
	
;;; DCB table for Read Host Slots

MATBL:
	.BYTE $70		; DDEVIC = $70 (Fuji)
	.BYTE $01		; DUNIT = 1
	.BYTE $D7		; DCOMND = Mount all
	.BYTE $00		; DSTATS = None
	.WORD 0 		; DBUF = Put buffer at end of memory
	.BYTE $FE		; DTIMLO = 4 min 15 seconds.
	.BYTE $00		; DRESVD = $00
	.WORD 0			; DBYT
PREPAD:	.WORD $00		; DAUX = 0

BOOT1:	.BY "PRESS "
	.BY +$80 " SELECT "
	.BY " TO BOOT CONFIG",$9B
BOOTWF:	.BY "WAITING FOR WIFI...",$9B
BOOTMT:	.BY "MOUNTING ALL SLOTS...",$9B
BOOTOK:	.BY "OK. BOOTING in 4 SECONDS",$9B
BOOTNO:	.BY "BOOT FAILED. BOOTING CONFIG...",$9B
BOOTSL:	.BY +$80 " SELECT "
	.BY " PRESSED, BOOTING CONFIG...",$9B
	
	.PRINT "Code Size Before Padding: ",PREPAD-START
	
	.BYTE	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; For padding calc below.
	
	.ALIGN	$80,$00		; 128 byte align for sectors.

END:	
	.PRINT "HDR: ",HDR
	.PRINT "END: ",END
	.PRINT "Number of Sectors: ",SECLEN
	
