.PHONY: build src





CC = i686-elf-gcc
LD = i686-elf-ld
AS = nasm
CFLAGS = -ffreestanding -nostdlib -m32 -masm=intel -g -I include/
LDFLAGS = -Ttext 0x10000 --oformat binary

DEVICE ?= /dev/sda
LO_DEVICE := $(shell sudo losetup -f)

build:
	#nuckBoot
	$(AS) src/boot.asm -f bin -o build/boot.bin -l build/boot.l

	#kernel entry
	$(AS) src/kernel_entry.asm -f elf -o build/kernel_entry.o -l build/kernel_entry.l

	#kernel C files
	$(CC) $(CFLAGS) -c src/kernel.c -o build/kernel.o 
	$(CC) $(CFLAGS) -c src/loadIDT.c -o build/loadIDT.o

	$(LD) $(LDFLAGS) build/kernel_entry.o build/kernel.o build/loadIDT.o -o build/full-kernel.bin 

	cat build/boot.bin build/full-kernel.bin > build/nuckos.bin

	rm build/kernel_entry.o build/kernel.o build/loadIDT.o build/full-kernel.bin build/boot.bin

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

	#60 MiB + 2048 sectors
	sudo dd if=/dev/zero of=build/nuckos.dd bs=512 count=124928
	sudo chmod 644 build/nuckos.dd
	sudo chown mythsnipper:mythsnipper build/nuckos.dd

	sudo dd conv=notrunc if=build/nuckos.bin of=build/nuckos.dd

cp:
	lsblk
	sudo dd if=build/nuckos.dd of=$(DEVICE) bs=5MiB
	sudo sync

qemu:
	sudo qemu-system-x86_64 -drive format=raw,file=build/nuckos.dd -smp 1 -m 1G
	
clean:
	sudo rm -f build/*
