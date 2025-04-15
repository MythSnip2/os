.PHONY: build src test

DEVICE ?= /dev/sda
LO_DEVICE := $(shell sudo losetup -f)
TARGET ?= src/boot.asm
OUT ?= 

test: clean build mkimg qemu

build:
	nasm $(TARGET) -f bin -o build/boot.bin

mkimg:
	#fill boot.dd with 6MiB zeroes
	sudo dd if=/dev/zero of=build/boot.dd bs=$$(echo $$((1024 * 1024))) count=6
	#create MBR table and add 4MB primary part starting at sector 2048
	echo -e "g\nn p\n1\n2048\n+4M\nt 1\n1\nw\n" | sudo fdisk build/boot.dd
	#set up a loopback for boot.dd where offset is 2048 sectors and size limit is 256MB
	sudo losetup -o $$(echo $$((1024 * 1024))) --sizelimit $$(echo $$((256 * 1024 * 1024))) $(LO_DEVICE) build/boot.dd
	#format to FAT12 fs EFI System
	sudo mkfs.vfat -F12 -n "EFI System" $(LO_DEVICE)
	#detach loopback
	sudo losetup -d $(LO_DEVICE)
	#write MBR to disk image
	sudo dd if=build/boot.bin of=build/boot.dd conv=notrunc bs=446 count=1
	sudo dd if=build/boot.bin of=build/boot.dd conv=notrunc bs=1 count=2 skip=510 seek=510
	sudo dd if=build/boot.bin of=build/boot.dd conv=notrunc bs=512 skip=1 seek=3 #copy rest of boot.bin
	
cpimg:
	sudo dd if=build/boot.dd of=$(DEVICE) bs=$$(echo $$((4 * 1024 * 1024)))

qemu:
	sudo qemu-system-x86_64 -enable-kvm -cpu host -drive format=raw,file=build/boot.dd

clean:
	sudo rm -f build/*
