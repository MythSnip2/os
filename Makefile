.PHONY: build src test

DEVICE ?= /dev/sda
LO_DEVICE := $(shell sudo losetup -f)
TARGET ?= src/boot.asm
OUT ?= 

all: clean build mkimg

mount: clean build mkimg cpimg

test: clean build mkimg qemu

testcpp:
	g++ test.cpp -o test
	./test

build:
	nasm $(TARGET) -f bin -o build/boot.bin

mkimg:
	sudo dd if=/dev/zero of=build/bootfs.dd bs=$$(echo $$((1024 * 1024))) count=6
	echo -e "g\nn p\n1\n2048\n+4M\nt 1\n1\nw\n" | sudo fdisk build/bootfs.dd
	sudo losetup -o $$(echo $$((1024 * 1024))) --sizelimit $$(echo $$((256 * 1024 * 1024))) $(LO_DEVICE) build/bootfs.dd
	sudo mkfs.vfat -F12 -n "EFI System" $(LO_DEVICE)
	sudo losetup -d $(LO_DEVICE)
	sudo dd if=build/boot.bin of=build/bootfs.dd conv=notrunc bs=446 count=1
	sudo dd if=build/boot.bin of=build/bootfs.dd conv=notrunc bs=1 count=2 skip=510 seek=510
	sudo dd if=build/boot.bin of=build/bootfs.dd conv=notrunc bs=512 skip=1 seek=3 #copy rest of boot.bin
	mv build/bootfs.dd build/boot.dd
	
cpimg:
	sudo dd if=build/boot.dd of=$(DEVICE) bs=$$(echo $$((4 * 1024 * 1024)))

qemu:
	sudo qemu-system-x86_64 -enable-kvm -cpu host -drive format=raw,file=build/boot.dd

clean:
	sudo rm -f build/*
