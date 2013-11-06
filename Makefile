PREFIX = /usr/local
TARGET = x86_64-w64-mingw32

BINUTILS = 2.23.2
GCC = 4.8.2

HOSTCC=$(shell which cc)
HOSTCXX=$(shell which c++)
OPTFLAGS = -O3 -msse2 -mfpmath=sse -mtune=generic -funroll-loops -funswitch-loops -fomit-frame-pointer
CFLAGS += $(OPTFLAGS)
CXXFLAGS += $(OPTFLAGS)

all: gcc.stamp pthread.stamp

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
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	make -C $(basename $@)
	make -C $(basename $@) -j5 install
	touch $@

gcc-boot.stamp: ../gcc-$(GCC) headers.stamp binutils.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --target=$(TARGET) --enable-languages=c,c++,objc,obj-c++ --disable-nls --disable-multilib --enable-lto \
		CC=$(HOSTCC) CXX=$(HOSTCXX) CXXCPP="$(HOSTCXX) -E" \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	make -C $(basename $@) -j2 all-gcc
	make -C $(basename $@) -j5 install-gcc
	touch $@

crt.stamp: ../mingw-w64 gcc-boot.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --host=$(TARGET) --prefix=$(PREFIX)/$(TARGET) \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	make -C $(basename $@) -j5
	make -C $(basename $@) -j5 install
	touch $@

pthread.stamp: ../pthread gcc.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --host=$(TARGET) --prefix=$(PREFIX)/$(TARGET) --disable-shared \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	make -C $(basename $@) -j5
	make -C $(basename $@) -j5 install
	if [ -f "$(PREFIX)/$(TARGET)/lib/libwinpthread.a" ]; then \
		cp -f "$(PREFIX)/$(TARGET)/lib/libwinpthread.a" "$(PREFIX)/$(TARGET)/lib/libpthread.a"; \
	fi;
	touch $@

gcc.stamp: ../gcc-$(GCC) crt.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --target=$(TARGET) --enable-languages=c,c++,objc,obj-c++ --disable-nls --disable-multilib --enable-lto \
		CC=$(HOSTCC) CXX=$(HOSTCXX) CXXCPP="$(HOSTCXX) -E" \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	make -C $(basename $@) -j2
	make -C $(basename $@) -j5 install
	touch $@

@PHONY: all clean
