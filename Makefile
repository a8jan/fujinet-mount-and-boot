##
## mount-and-boot makefile
##

.PHONY: all clean

all: mount-and-boot.atr

mount-and-boot.atr:
	mads src/mount-and-boot.s -l:ndev.lst -o:mount-and-boot.atr

