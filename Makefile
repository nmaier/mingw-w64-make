-include build*.mk

SUDO ?= sudo
PREFIX ?= /usr/local
TARCH ?= x86_64
TARGET ?= $(TARCH)-w64-mingw32
HOST_PREFIX ?= $(PWD)/hostlibs

BINUTILS ?= 2.24
GCC ?= 4.8.2

HOST_CC ?= $(shell which cc)
HOST_CXX ?= $(shell which c++)

HOST_OPTFLAGS ?= -march=native -O3 -mfpmath=sse -funroll-loops -funswitch-loops -fomit-frame-pointer
HOST_CFLAGS += $(HOST_OPTFLAGS)
HOST_CXXFLAGS += $(HOST_OPTFLAGS)

OPTFLAGS ?= -O3 -msse2 -mfpmath=sse -mtune=generic -funroll-loops -funswitch-loops -fomit-frame-pointer
CFLAGS += $(OPTFLAGS)
CXXFLAGS += $(OPTFLAGS)

LIBGMP = $(HOST_PREFIX)/lib/libgmp.a
LIBMPFR = $(HOST_PREFIX)/lib/libmpfr.a
LIBMPC = $(HOST_PREFIX)/lib/libmpc.a
LIBISL = $(HOST_PREFIX)/lib/libisl.a
LIBPPL11 = $(HOST_PREFIX)/lib/libppl_c.a
LIBCLOOGISL = $(HOST_PREFIX)/lib/libcloog-isl.a
LIBCLOOGPPL = $(HOST_PREFIX)/lib/libcloog.a

all: info gcc.stamp pthread.stamp

info:
	@echo
	@echo Building toolchain using:
	@echo
	@echo 'CC:            $(HOST_CC)'
	@echo 'CXX:           $(HOST_CXX)'
	@echo 'TARCH:         $(TARCH)'
	@echo 'TARGET:        $(TARGET)'
	@echo 'PREFIX:        $(PREFIX)'
	@echo 'OPTFLAGS:      $(OPTFLAGS)'
	@echo 'HOST_OPTFLAGS: $(HOST_OPTFLAGS)'
	@echo
	@echo 'GCC:      $(GCC)'
	@echo 'BINUTILS: $(BINUTILS)'
	@echo
	@echo

clean:
	rm -f *.stamp
	rm -rf headers gmp mpfr mpc isl cloog cloog-ppl binutils gcc-boot crt gcc pthread ppl-0.11

clean-host:
	rm -rf $(HOST_PREFIX)

clean-all: clean clean-host

headers.stamp: ../mingw-w64/mingw-w64-headers
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --host=$(TARGET) --prefix=$(PREFIX)/$(TARGET) --enable-idl
	$(MAKE) -j2 -C $(basename $@)
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

$(LIBGMP): ../gmp
	mkdir -p $(<F) && cd $(<F) && \
		../$</configure --prefix=$(HOST_PREFIX) --enable-cxx --disable-shared --enable-static --with-pic \
		CC=$(HOST_CC) CXX=$(HOST_CXX) \
		CFLAGS="$(HOST_CFLAGS)" CXXFLAGS="$(HOST_CXXFLAGS)"
	$(MAKE) -j5 -C $(<F)
	$(MAKE) -C $(<F) -j5 install

$(LIBMPFR): ../mpfr $(LIBGMP)
	mkdir -p $(<F) && cd $(<F) && \
		../$</configure --prefix=$(HOST_PREFIX) --with-gmp=$(HOST_PREFIX) --disable-shared --enable-static \
		CC=$(HOST_CC) CXX=$(HOST_CXX) \
		CFLAGS="$(HOST_CFLAGS)" CXXFLAGS="$(HOST_CXXFLAGS)"
	$(MAKE) -j5 -C $(<F)
	$(MAKE) -C $(<F) -j5 install

$(LIBMPC): ../mpc $(LIBMPFR)
	mkdir -p $(<F) && cd $(<F) && \
		../$</configure --prefix=$(HOST_PREFIX) --with-gmp=$(HOST_PREFIX) --with-mpfr=$(HOST_PREFIX) --disable-shared --enable-static \
		CC=$(HOST_CC) CXX=$(HOST_CXX) \
		CFLAGS="$(HOST_CFLAGS)" CXXFLAGS="$(HOST_CXXFLAGS)"
	$(MAKE) -j5 -C $(<F)
	$(MAKE) -C $(<F) -j5 install

$(LIBISL): ../isl $(LIBGMP)
	mkdir -p $(<F) && cd $(<F) && \
		../$</configure --prefix=$(HOST_PREFIX) --with-gmp=system --with-gmp-prefix=$(HOST_PREFIX) --disable-shared --enable-static \
		CC=$(HOST_CC) CXX=$(HOST_CXX) \
		CFLAGS="$(HOST_CFLAGS)" CXXFLAGS="$(HOST_CXXFLAGS)"
	$(MAKE) -j5 -C $(<F)
	$(MAKE) -C $(<F) -j5 install

$(LIBCLOOGISL): ../cloog $(LIBGMP) $(LIBISL)
	mkdir -p $(<F) && cd $(<F) && \
		../$</configure --prefix=$(HOST_PREFIX) --with-isl=system --with-isl-prefix=$(HOST_PREFIX) --with-gmp=system --with-gmp-prefix=$(HOST_PREFIX) --disable-shared --enable-static \
		CC=$(HOST_CC) CXX=$(HOST_CXX) \
		CFLAGS="$(HOST_CFLAGS)" CXXFLAGS="$(HOST_CXXFLAGS)"
	$(MAKE) -j5 -C $(<F)
	$(MAKE) -C $(<F) -j5 install

$(LIBPPL11): ../ppl-0.11 $(LIBGMP)
	mkdir -p $(<F) && cd $(<F) && \
		../$</configure --prefix=$(HOST_PREFIX) --with-gmp-prefix=$(HOST_PREFIX) --disable-shared --enable-static \
		CC=$(HOST_CC) CXX=$(HOST_CXX) \
		CFLAGS="$(HOST_CFLAGS)" CXXFLAGS="$(HOST_CXXFLAGS)"
	$(MAKE) -j5 -C $(<F)
	$(MAKE) -C $(<F) -j5 install

$(LIBCLOOGPPL): ../cloog-ppl $(LIBGMP) $(LIBPPL11)
	mkdir -p $(<F) && cd $(<F) && \
		../$</configure --prefix=$(HOST_PREFIX) --includedir=$(HOST_PREFIX)/include/cloog-ppl --with-gmp=$(HOST_PREFIX) --with-ppl=$(HOST_PREFIX) --with-bits=gmp --disable-shared --enable-static \
		CC=$(HOST_CC) CXX=$(HOST_CXX) \
		CFLAGS="$(HOST_CFLAGS)" CXXFLAGS="$(HOST_CXXFLAGS)"
	$(MAKE) -j5 -C $(<F)
	$(MAKE) -C $(<F) -j5 install

binutils.stamp: ../binutils-$(BINUTILS) $(LIBGMP) $(LIBMPFR) $(LIBMPC) $(LIBCLOOGPPL)
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --prefix=$(PREFIX) --target=$(TARGET) --enable-targets=$(TARGET) --enable-lto --disable-nls --disable-multilib \
		--with-gmp=$(HOST_PREFIX) --with-mpfr=$(HOST_PREFIX) --with-mpc=$(HOST_PREFIX) --with-cloog=$(HOST_PREFIX) --with-cloog-include=$(HOST_PREFIX)/include/cloog-ppl \
		CC=$(HOST_CC) CXX=$(HOST_CXX) \
		CFLAGS="$(HOST_CFLAGS) -Wno-unused-value" CXXFLAGS="$(HOST_CXXFLAGS)"
	$(MAKE) -j2 -C $(basename $@)
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

gcc-boot.stamp: ../gcc-$(GCC) headers.stamp binutils.stamp $(LIBGMP) $(LIBMPFR) $(LIBMPC) $(LIBISL) $(LIBCLOOGISL)
	mkdir -p $(basename $@) && cd $(basename $@) && \
		../$</configure --target=$(TARGET) --enable-languages=c,c++,objc,obj-c++ --disable-nls --disable-multilib --enable-lto \
		--with-gmp=$(HOST_PREFIX) --with-mpfr=$(HOST_PREFIX) --with-mpc=$(HOST_PREFIX) --with-cloog=$(HOST_PREFIX) --with-isl=$(HOST_PREFIX) \
		CC=$(HOST_CC) CXX=$(HOST_CXX) CXXCPP="$(HOST_CXX) -E" \
		CFLAGS="$(HOST_CFLAGS)" CXXFLAGS="$(HOST_CXXFLAGS)" \
		CFLAGS_FOR_TARGET="$(CFLAGS)" CXXFLAGS_FOR_TARGET="$(CXXFLAGS)"
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
		CFLAGS="$(CFLAGS)"
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
		CC=$(HOST_CC) CXX=$(HOST_CXX) CXXCPP="$(HOST_CXX) -E" \
		CFLAGS="$(HOST_CFLAGS)" CXXFLAGS="$(HOST_CXXFLAGS)" \
		CFLAGS_FOR_TARGET="$(CFLAGS)" CXXFLAGS_FOR_TARGET="$(CXXFLAGS)"
	$(MAKE) -C $(basename $@) -j2
	$(SUDO) $(MAKE) -C $(basename $@) -j5 install
	touch $@

@PHONY: all clean info
