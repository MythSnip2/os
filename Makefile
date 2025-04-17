.PHONY: build src test

DEVICE ?= /dev/sda
LO_DEVICE := $(shell sudo losetup -f)
TARGET ?= src/boot.asm
OUT ?= 

test: clean build mkimg qemu

build:
	nasm $(TARGET) -f bin -o build/boot.bin

mkimg:
	#fill boot.dd with 264192 sectors zeroes:
	#data:        MBR  loader  part1
	#sectors:      1    2047   262144(128MiB)
	#starting:     0     1     2048
	#ending:       0    2047   264191
	#
	sudo dd if=/dev/zero of=build/boot.dd bs=512 count=264192

	#create MBR table and do partitioning
	echo -e "o\nn\np\n1\n2048\n\nt 1\nb\na\nw\n" | sudo fdisk build/boot.dd

	#set up a loopback for boot.dd where offset is 2048 sectors and size limit is 2048 sectors
	sudo losetup -o 1048576 $(LO_DEVICE) build/boot.dd
	
	#format to FAT32 EFI System
	sudo mkfs.vfat -D 0x85 -F 32 -n "EFI System" -s 8 -v $(LO_DEVICE)
	
	#detach loopback
	sudo losetup -d $(LO_DEVICE)
	
	#write MBR to disk image
	sudo dd if=build/boot.bin of=build/boot.dd conv=notrunc bs=446 count=1
	sudo dd if=build/boot.bin of=build/boot.dd conv=notrunc bs=1 count=2 skip=510 seek=510
	sudo dd if=build/boot.bin of=build/boot.dd conv=notrunc bs=512 skip=1 seek=3 #copy rest of boot.bin
	sudo sync

mk:
	#create MBR table and do partitioning
	#echo -e "o\nn\np\n1\n1\n\nt 1\nb\na\nw\n" | sudo fdisk build/boot.dd

	sudo cp build/boot.bin build/boot.dd

cpimg:
	sudo dd if=build/boot.dd of=$(DEVICE) bs=$$(echo $$((8 * 1024 * 1024)))
	sudo sync

qemu:
	sudo qemu-system-x86_64 -enable-kvm -cpu host -drive format=raw,file=build/boot.dd

clean:
	sudo rm -f build/*
