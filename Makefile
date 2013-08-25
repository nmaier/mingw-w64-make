PREFIX = /usr/local
TARGET = x86_64-w64-mingw32

BINUTILS = 2.23.2
GCC = 4.8.1

HOSTCC=$(shell which cc)
HOSTCXX=$(shell which c++)

all: gcc.stamp

clean:
	rm -f *.stamp
	rm -rf headers binutils gcc-boot crt gcc

headers.stamp: ../mingw-w64/mingw-w64-headers
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --host=$(TARGET) --prefix=$(PREFIX)/$(TARGET) --enable-idl
	make -C $(basename $@)
	make -C $(basename $@) -j5 install
	touch $@

binutils.stamp: ../binutils-$(BINUTILS)
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --prefix=$(PREFIX) --target=$(TARGET) --enable-targets=$(TARGET) --enable-lto --disable-nls --disable-multilib \
		CC=$(HOSTCC) CXX=$(HOSTCXX) \
		CFLAGS="-O3 -mtune=generic"
	make -C $(basename $@)
	make -C $(basename $@) -j5 install
	touch $@

gcc-boot.stamp: ../gcc-$(GCC) headers.stamp binutils.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --target=$(TARGET) --enable-languages=c,c++,objc,obj-c++ --disable-nls --disable-multilib --enable-lto \
		CC=$(HOSTCC) CXX=$(HOSTCXX) CXXCPP="$(HOSTCXX) -E"
	make -C $(basename $@) -j5 all-gcc
	make -C $(basename $@) -j5 install-gcc
	touch $@

crt.stamp: ../mingw-w64 gcc-boot.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --host=$(TARGET) --prefix=$(PREFIX)/$(TARGET) \
		CFLAGS="-O3 -march=core2 -mtune=generic -mfpmath=sse"
	make -C $(basename $@) -j5
	make -C $(basename $@) -j5 install
	touch $@

gcc.stamp: ../gcc-$(GCC) crt.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --target=$(TARGET) --enable-languages=c,c++,objc,obj-c++ --disable-nls --disable-multilib --enable-lto \
		CC=$(HOSTCC) CXX=$(HOSTCXX) CXXCPP="$(HOSTCXX) -E" \
		CFLAGS="-O3 -march=core2 -mtune=generic -mfpmath=sse"
	make -C $(basename $@)
	make -C $(basename $@) -j5 install
	touch $@

@PHONY: all clean
