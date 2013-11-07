SUDO = sudo
PREFIX = /usr/local
TARCH = x86_64
TARGET = $(TARCH)-w64-mingw32
HOST_PREFIX = $(PREFIX)/$(TARGET)/host

BINUTILS = 2.23.2
GCC = 4.8.2

HOSTCC=$(shell which cc)
HOSTCXX=$(shell which c++)
OPTFLAGS = -O3 -msse2 -mfpmath=sse -mtune=generic -funroll-loops -funswitch-loops -fomit-frame-pointer
CFLAGS += $(OPTFLAGS)
CXXFLAGS += $(OPTFLAGS)

ifeq (,$(findstring i686,$(TARGET)))
	CFLAGS_PTHREAD = $(CFLAGS)
else
	CFLAGS_PTHREAD = -O3 -mtune=generic
endif

all: gcc.stamp pthread.stamp

clean:
	rm -f *.stamp
	rm -rf headers gmp mpfr mpc isl cloog cloog-ppl binutils gcc-boot crt gcc pthread
	$(SUDO) rm -rf ppl-0.11

headers.stamp: ../mingw-w64/mingw-w64-headers
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --host=$(TARGET) --prefix=$(PREFIX)/$(TARGET) --enable-idl
	$(MAKE) -C $(basename $@)
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

gmp.stamp: ../gmp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --prefix=$(HOST_PREFIX) --enable-cxx --disable-shared --enable-static \
		CC=$(HOSTCC) CXX=$(HOSTCXX) \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $(basename $@)
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

mpfr.stamp: ../mpfr gmp.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --prefix=$(HOST_PREFIX) --with-gmp=$(HOST_PREFIX) --disable-shared --enable-static \
		CC=$(HOSTCC) CXX=$(HOSTCXX) \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $(basename $@)
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

mpc.stamp: ../mpc gmp.stamp mpfr.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --prefix=$(HOST_PREFIX) --with-gmp=$(HOST_PREFIX) --with-mpfr=$(HOST_PREFIX) --disable-shared --enable-static \
		CC=$(HOSTCC) CXX=$(HOSTCXX) \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $(basename $@)
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

isl.stamp: ../isl gmp.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --prefix=$(HOST_PREFIX) --with-gmp=system --with-gmp-prefix=$(HOST_PREFIX) --disable-shared --enable-static \
		CC=$(HOSTCC) CXX=$(HOSTCXX) \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $(basename $@)
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

cloog.stamp: ../cloog gmp.stamp isl.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --prefix=$(HOST_PREFIX) --with-isl=system --with-isl-prefix=$(HOST_PREFIX) --with-gmp=system --with-gmp-prefix=$(HOST_PREFIX) --disable-shared --enable-static \
		CC=$(HOSTCC) CXX=$(HOSTCXX) \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $(basename $@)
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

ppl-0.11.stamp: ../ppl-0.11 gmp.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --prefix=$(HOST_PREFIX) --with-gmp-prefix=$(HOST_PREFIX) --disable-shared --enable-static \
		CC=$(HOSTCC) CXX=$(HOSTCXX) \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $(basename $@)
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

cloog-ppl.stamp: ../cloog-ppl gmp.stamp ppl-0.11.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --prefix=$(HOST_PREFIX) --includedir=$(HOST_PREFIX)/include/cloog-ppl --with-gmp=$(HOST_PREFIX) --with-ppl=$(HOST_PREFIX) --with-bits=gmp --disable-shared --enable-static \
		CC=$(HOSTCC) CXX=$(HOSTCXX) \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $(basename $@)
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

binutils.stamp: ../binutils-$(BINUTILS) gmp.stamp mpfr.stamp mpc.stamp cloog-ppl.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --prefix=$(PREFIX) --target=$(TARGET) --enable-targets=$(TARGET) --enable-lto --disable-nls --disable-multilib \
		--with-gmp=$(HOST_PREFIX) --with-mpfr=$(HOST_PREFIX) --with-mpc=$(HOST_PREFIX) --with-cloog=$(HOST_PREFIX) --with-cloog-include=$(HOST_PREFIX)/include/cloog-ppl \
		CC=$(HOSTCC) CXX=$(HOSTCXX) \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $(basename $@)
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

gcc-boot.stamp: ../gcc-$(GCC) headers.stamp binutils.stamp gmp.stamp mpfr.stamp mpc.stamp isl.stamp cloog.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --target=$(TARGET) --enable-languages=c,c++,objc,obj-c++ --disable-nls --disable-multilib --enable-lto \
		--with-gmp=$(HOST_PREFIX) --with-mpfr=$(HOST_PREFIX) --with-mpc=$(HOST_PREFIX) --with-cloog=$(HOST_PREFIX) --with-isl=$(HOST_PREFIX) \
		CC=$(HOSTCC) CXX=$(HOSTCXX) CXXCPP="$(HOSTCXX) -E" \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $(basename $@) -j2 all-gcc
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install-gcc
	touch $@

crt.stamp: ../mingw-w64 gcc-boot.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --host=$(TARGET) --prefix=$(PREFIX)/$(TARGET) \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $(basename $@) -j5
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

pthread.stamp: ../mingw-w64/mingw-w64-libraries/winpthreads gcc.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --host=$(TARGET) --prefix=$(PREFIX)/$(TARGET) --disable-shared \
		CFLAGS="$(CFLAGS_PTHREAD)"
	$(MAKE) -C $(basename $@) -j5
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	if [ -f "$(PREFIX)/$(TARGET)/lib/libwinpthread.a" ]; then \
		$(SUDO) cp -f "$(PREFIX)/$(TARGET)/lib/libwinpthread.a" "$(PREFIX)/$(TARGET)/lib/libpthread.a"; \
	fi;
	touch $@

gcc.stamp: ../gcc-$(GCC) crt.stamp
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --target=$(TARGET) --enable-languages=c,c++,objc,obj-c++ --disable-nls --disable-multilib --enable-lto \
		--with-gmp=$(HOST_PREFIX) --with-mpfr=$(HOST_PREFIX) --with-mpc=$(HOST_PREFIX) --with-cloog=$(HOST_PREFIX) --with-isl=$(HOST_PREFIX) \
		CC=$(HOSTCC) CXX=$(HOSTCXX) CXXCPP="$(HOSTCXX) -E" \
		CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $(basename $@) -j2
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

@PHONY: all clean
