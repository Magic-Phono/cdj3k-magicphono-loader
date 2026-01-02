SHELL=/bin/bash
FIRMWARES=LOADER SYSINFO

.PHONY: all clean

all: $(FIRMWARES)

$(FIRMWARES): $(FIRMWARE=$(.TARGET))

CDJ3Kv$(FIRMWARE).UPD: LOOP=$(shell sudo losetup -f)

CDJ3Kv$(FIRMWARE).UPD CDJ3Kv$(FIRMWARE).UPD.crc32: pdj.tar.gz CDJ3K-RK3399.iso src/$(FIRMWARE)/* src/$(FIRMWARE)/.*
	genisoimage -R -J -input-charset utf-8 --graft-points -o CDJ3Kv000.UPD images/CDJ3K-RK3399.iso=CDJ3K-RK3399.iso src/$(.TARGET)/* src/$(.TARGET)/.*
	isoinfo -R -l -i CDJ3Kv$(.TARGET).UPD
#   Make room for LUKS header
	dd if=/dev/zero bs=32M count=1 >> CDJ3Kv$(.TARGET).UPD
	sudo losetup ${LOOP} CDJ3Kv$(.TARGET).UPD
	sudo cryptsetup reencrypt \
		--batch-mode \
		--encrypt \
		--reduce-device-size 32M \
		--type luks1 \
		--cipher aes-xts-plain64 \
		--key-size 512 \
		--key-file aes256.key \
		$(LOOP) cdj_firmware
	sudo losetup -d $(LOOP)
#   Calculate CRC before writing magic trailer
	./crc32.py CDJ3Kv$(.TARGET).UPD > CDJ3Kv$(.TARGET).UPD.crc32
	echo -n -e 'XDJ-RR0.00\x00' >> CDJ3Kv$(.TARGET).UPD
	cat CDJ3Kv$(.TARGET).UPD.crc32 >> CDJ3Kv$(.TARGET).UPD


# CDJ3KvMP_LOADER.UPD: LOOP=$(shell sudo losetup -f)

# CDJ3KvMP_LOADER.UPD CDJ3Kv000.UPD.crc32: pdj.tar.gz CDJ3K-RK3399.iso src/* src/.*
# 	genisoimage -R -J -input-charset utf-8 --graft-points -o CDJ3Kv000.UPD images/CDJ3K-RK3399.iso=CDJ3K-RK3399.iso src/* src/.*
# 	isoinfo -R -l -i CDJ3Kv000.UPD
# #   Make room for LUKS header
# 	dd if=/dev/zero bs=32M count=1 >> CDJ3Kv000.UPD
# 	sudo losetup ${LOOP} CDJ3Kv000.UPD
# 	sudo cryptsetup reencrypt \
# 		--batch-mode \
# 		--encrypt \
# 		--reduce-device-size 32M \
# 		--type luks1 \
# 		--cipher aes-xts-plain64 \
# 		--key-size 512 \
# 		--key-file aes256.key \
# 		$(LOOP) cdj_firmware
# 	sudo losetup -d $(LOOP)
# #   Calculate CRC before writing magic trailer
# 	./crc32.py CDJ3Kv000.UPD > CDJ3Kv000.UPD.crc32
# 	echo -n -e 'XDJ-RR0.00\x00' >> CDJ3Kv000.UPD
# 	cat CDJ3Kv000.UPD.crc32 >> CDJ3Kv000.UPD

pdj.tar.gz: pdj/*
	tar --no-xattrs --exclude ".DS_Store" -czvf pdj.tar.gz -C pdj/ .
	mv pdj.tar.gz src/

CDJ3K-RK3399.iso: pdj.tar.gz src/$(FIRMWARE)/* src/$(FIRMWARE)/.*
	genisoimage -R -J -input-charset utf-8 -o CDJ3K-RK3399.iso src/$(.TARGET)/* src/$(.TARGET)/.*
	isoinfo -R -l -i CDJ3K-RK3399.iso

clean: $(FIRMWARES)
	rm -f src/pdj.tar.gz
	rm -f CDJ3Kv$@.UPD
	rm -f CDJ3Kv$@.UPD.crc32
	rm -f CDJ3K-RK3399.iso
