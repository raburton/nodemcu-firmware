#  copyright (c) 2010 Espressif System
#
.NOTPARALLEL:

# SDK version NodeMCU is locked to
SDK_VER:=1.5.4.1

# no patch: SDK_BASE_VER equals SDK_VER and sdk dir depends on sdk_extracted
#SDK_BASE_VER:=SDK_VER
#SDK_DIR_DEPENDS:=sdk_extracted
# with patch: SDK_BASE_VER differs from SDK_VER and sdk dir depends on sdk_patched
SDK_BASE_VER:=1.5.4
SDK_DIR_DEPENDS:=sdk_patched

SDK_FILE_VER:=$(SDK_BASE_VER)_16_05_20
SDK_FILE_ID:=1469
SDK_FILE_SHA1:=868784bd37d47f31d52b81f133aa1fb70c58e17d
SDK_PATCH_VER:=$(SDK_VER)_patch_20160704
SDK_PATCH_ID:=1572
SDK_PATCH_SHA1:=388d9e91df74e3b49fca126da482cf822cf1ebf1
# Ensure we search "our" SDK before the tool-chain's SDK (if any)
TOP_DIR:=$(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SDK_DIR:=$(TOP_DIR)/sdk/esp_iot_sdk_v$(SDK_VER)
CCFLAGS:= -I$(TOP_DIR)/sdk-overrides/include -I$(SDK_DIR)/include
LDFLAGS:= -L$(TOP_DIR)/sdk-overrides/lib -L$(SDK_DIR)/lib -L$(SDK_DIR)/ld $(LDFLAGS)

#############################################################
# Select compile
#
ifeq ($(OS),Windows_NT)
# WIN32
# We are under windows.
	ifeq ($(XTENSA_CORE),lx106)
		# It is xcc
		AR = xt-ar
		CC = xt-xcc
		NM = xt-nm
		CPP = xt-cpp
		OBJCOPY = xt-objcopy
		#MAKE = xt-make
		CCFLAGS += -Os --rename-section .text=.irom0.text --rename-section .literal=.irom0.literal
	else 
		# It is gcc, may be cygwin
		# Can we use -fdata-sections?
		CCFLAGS += -Os -ffunction-sections -fno-jump-tables -fdata-sections
		AR = xtensa-lx106-elf-ar
		CC = xtensa-lx106-elf-gcc
		NM = xtensa-lx106-elf-nm
		CPP = xtensa-lx106-elf-cpp
		OBJCOPY = xtensa-lx106-elf-objcopy
	endif
	FIRMWAREDIR = ..\\bin\\
	ifndef COMPORT
		ESPPORT = com1
	else
		ESPPORT = $(COMPORT)
	endif
    ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
# ->AMD64
    endif
    ifeq ($(PROCESSOR_ARCHITECTURE),x86)
# ->IA32
    endif
else
# We are under other system, may be Linux. Assume using gcc.
	# Can we use -fdata-sections?
	ifndef COMPORT
		ESPPORT = /dev/ttyUSB0
	else
		ESPPORT = $(COMPORT)
	endif
	CCFLAGS += -Os -ffunction-sections -fno-jump-tables -fdata-sections
	AR = xtensa-lx106-elf-ar
	CC = xtensa-lx106-elf-gcc
	NM = xtensa-lx106-elf-nm
	CPP = xtensa-lx106-elf-cpp
	OBJCOPY = xtensa-lx106-elf-objcopy
	FIRMWAREDIR = ../bin/
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
# LINUX
    endif
    ifeq ($(UNAME_S),Darwin)
# OSX
    endif
    UNAME_P := $(shell uname -p)
    ifeq ($(UNAME_P),x86_64)
# ->AMD64
    endif
    ifneq ($(filter %86,$(UNAME_P)),)
# ->IA32
    endif
    ifneq ($(filter arm%,$(UNAME_P)),)
# ->ARM
    endif
endif
#############################################################
ESPTOOL ?= ../tools/esptool.py
ESPTOOL2 ?= esptool2
RBOOT_E2_SECTS     ?= .text .data .rodata
RBOOT_E2_USER_ARGS ?= -quiet -bin -boot2 -iromchksum

V ?= $(VERBOSE)
ifeq ("$(V)","1")
Q :=
QECHO := @true
VECHO := @echo
MAKEPDIR :=
else
Q := @
QECHO := @echo
VECHO := @true
MAKEPDIR := --no-print-directory
endif


CSRCS ?= $(wildcard *.c)
ASRCs ?= $(wildcard *.s)
ASRCS ?= $(wildcard *.S)
SUBDIRS ?= $(patsubst %/,%,$(dir $(filter-out tools/Makefile,$(wildcard */Makefile))))

ODIR := .output
OBJODIR := $(ODIR)/$(TARGET)/$(FLAVOR)/obj

OBJS := $(CSRCS:%.c=$(OBJODIR)/%.o) \
        $(ASRCs:%.s=$(OBJODIR)/%.o) \
        $(ASRCS:%.S=$(OBJODIR)/%.o)

DEPS := $(CSRCS:%.c=$(OBJODIR)/%.d) \
        $(ASRCs:%.s=$(OBJODIR)/%.d) \
        $(ASRCS:%.S=$(OBJODIR)/%.d)

LIBODIR := $(ODIR)/$(TARGET)/$(FLAVOR)/lib
OLIBS := $(GEN_LIBS:%=$(LIBODIR)/%)

IMAGEODIR := $(ODIR)/$(TARGET)/$(FLAVOR)/image
OIMAGES := $(GEN_IMAGES:%=$(IMAGEODIR)/%)

BINODIR := $(TOP_DIR)/bin
OBINS := $(GEN_BINS:%=$(BINODIR)/%)

ifndef PDIR
ifneq ($(wildcard $(TOP_DIR)/local/fs/*),)
SPECIAL_MKTARGETS += spiffs-image
else
SPECIAL_MKTARGETS += spiffs-image-remove
endif
endif

#
# Note: 
# https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html
# If you add global optimize options like "-O2" here 
# they will override "-Os" defined above.
# "-Os" should be used to reduce code size
#
CCFLAGS += 			\
	-g			\
	-Wpointer-arith		\
	-Wundef			\
	-Werror			\
	-Wl,-EL			\
	-fno-inline-functions	\
	-nostdlib       \
	-mlongcalls	\
	-mtext-section-literals
#	-Wall			

CFLAGS = $(CCFLAGS) $(DEFINES) $(EXTRA_CCFLAGS) $(STD_CFLAGS) $(INCLUDES)
DFLAGS = $(CCFLAGS) $(DDEFINES) $(EXTRA_CCFLAGS) $(STD_CFLAGS) $(INCLUDES)


#############################################################
# Functions
#

define ShortcutRule
$(1): .subdirs $(2)/$(1)
endef

define MakeLibrary
DEP_LIBS_$(1) = $$(foreach lib,$$(filter %.a,$$(COMPONENTS_$(1))),$$(dir $$(lib))$$(LIBODIR)/$$(notdir $$(lib)))
DEP_OBJS_$(1) = $$(foreach obj,$$(filter %.o,$$(COMPONENTS_$(1))),$$(dir $$(obj))$$(OBJODIR)/$$(notdir $$(obj)))
$$(LIBODIR)/$(1).a: $$(OBJS) $$(DEP_OBJS_$(1)) $$(DEP_LIBS_$(1)) $$(DEPENDS_$(1))
	$(Q) mkdir -p $$(LIBODIR)
	$(Q) $$(if $$(filter %.a,$$?),mkdir -p $$(EXTRACT_DIR)_$(1))
	$(Q) $$(if $$(filter %.a,$$?),cd $$(EXTRACT_DIR)_$(1); $$(foreach lib,$$(filter %.a,$$?),$$(AR) xo $$(UP_EXTRACT_DIR)/$$(lib);))
	$(QECHO) AR $$@
	$(Q) $$(AR) ru $$@ $$(filter %.o,$$?) $$(if $$(filter %.a,$$?),$$(EXTRACT_DIR)_$(1)/*.o)
	$(Q) $$(if $$(filter %.a,$$?),$$(RM) -r $$(EXTRACT_DIR)_$(1))
endef

define MakeImage
DEP_LIBS_$(1) = $$(foreach lib,$$(filter %.a,$$(COMPONENTS_$(1))),$$(dir $$(lib))$$(LIBODIR)/$$(notdir $$(lib)))
DEP_OBJS_$(1) = $$(foreach obj,$$(filter %.o,$$(COMPONENTS_$(1))),$$(dir $$(obj))$$(OBJODIR)/$$(notdir $$(obj)))
$$(IMAGEODIR)/$(1).out: $$(OBJS) $$(DEP_OBJS_$(1)) $$(DEP_LIBS_$(1)) $$(DEPENDS_$(1))
	$(Q) mkdir -p $$(IMAGEODIR)
	$(QECHO) CC $$@
	$(Q) $$(CC) $$(LDFLAGS) $$(if $$(LINKFLAGS_$(1)),$$(LINKFLAGS_$(1)),$$(LINKFLAGS_DEFAULT) $$(OBJS) $$(DEP_OBJS_$(1)) $$(DEP_LIBS_$(1))) -o $$@
endef

$(BINODIR)/%.bin: $(IMAGEODIR)/%.out
	$(Q) mkdir -p $(BINODIR)
	$(QECHO) E2 $@
	$(Q) $(ESPTOOL2) $(RBOOT_E2_USER_ARGS) $< $@ $(RBOOT_E2_SECTS)

#############################################################
# Rules base
# Should be done in top-level makefile only
#

ifndef PDIR
# targets for top level only
RBOOT=bin/rboot.bin
LIBMAIN_SRC = $(SDK_DIR)/lib/libmain.a
LIBMAIN_DST = $(TOP_DIR)/sdk-overrides/lib/libmain2.a
endif
all:	$(SDK_DIR_DEPENDS) pre_build .subdirs $(LIBMAIN_DST) $(RBOOT) $(OBJS) $(OLIBS) $(OIMAGES) $(OBINS) $(SPECIAL_MKTARGETS)

.PHONY: sdk_extracted rboot
.PHONY: sdk_patched

sdk_extracted: $(TOP_DIR)/sdk/.extracted-$(SDK_BASE_VER)
sdk_patched: sdk_extracted $(TOP_DIR)/sdk/.patched-$(SDK_VER)


$(LIBMAIN_DST): $(LIBMAIN_SRC)
	@echo "OC $@"
	$(Q) $(OBJCOPY) -W Cache_Read_Enable_New $^ $@

$(TOP_DIR)/sdk/.extracted-$(SDK_BASE_VER): $(TOP_DIR)/cache/esp_iot_sdk_v$(SDK_FILE_VER).zip
	mkdir -p "$(dir $@)"
	(cd "$(dir $@)" && rm -fr esp_iot_sdk_v$(SDK_VER) ESP8266_NONOS_SDK && unzip $(TOP_DIR)/cache/esp_iot_sdk_v$(SDK_FILE_VER).zip ESP8266_NONOS_SDK/lib/* ESP8266_NONOS_SDK/ld/eagle.rom.addr.v6.ld ESP8266_NONOS_SDK/include/* )
	mv $(dir $@)/ESP8266_NONOS_SDK $(dir $@)/esp_iot_sdk_v$(SDK_VER)
	rm -f $(SDK_DIR)/lib/liblwip.a
	touch $@

$(TOP_DIR)/sdk/.patched-$(SDK_VER): $(TOP_DIR)/cache/esp_iot_sdk_v$(SDK_PATCH_VER).zip
	mkdir -p "$(dir $@)/patch"
	(cd "$(dir $@)/patch" && unzip $(TOP_DIR)/cache/esp_iot_sdk_v$(SDK_PATCH_VER)*.zip *.a && mv *.a $(SDK_DIR)/lib/)
	rmdir $(dir $@)/patch
	rm -f $(SDK_DIR)/lib/liblwip.a
	touch $@

$(TOP_DIR)/cache/esp_iot_sdk_v$(SDK_FILE_VER).zip:
	$(Q) mkdir -p "$(dir $@)"
	$(Q) wget --tries=10 --timeout=15 --waitretry=30 --read-timeout=20 --retry-connrefused http://bbs.espressif.com/download/file.php?id=$(SDK_FILE_ID) -O $@ || { rm -f "$@"; exit 1; }
	$(Q) (echo "$(SDK_FILE_SHA1)  $@" | sha1sum -c -) || { rm -f "$@"; exit 1; }

$(TOP_DIR)/cache/esp_iot_sdk_v$(SDK_PATCH_VER).zip:
	mkdir -p "$(dir $@)"
	wget --tries=10 --timeout=15 --waitretry=30 --read-timeout=20 --retry-connrefused http://bbs.espressif.com/download/file.php?id=$(SDK_PATCH_ID) -O $@ || { rm -f "$@"; exit 1; }
	(echo "$(SDK_PATCH_SHA1)  $@" | sha1sum -c -) || { rm -f "$@"; exit 1; }

clean:
	$(Q) $(foreach d, $(SUBDIRS), $(MAKE) -C $(d) clean;)
	$(Q) $(RM) -r $(ODIR)/$(TARGET)/$(FLAVOR)
	$(Q) $(RM) -r "$(TOP_DIR)/sdk"

clobber: $(SPECIAL_CLOBBER)
	$(Q) $(foreach d, $(SUBDIRS), $(MAKE) $(MAKEPDIR) -C $(d) clobber;)
	$(Q) $(RM) -r $(ODIR)

flash: 
ifndef PDIR
	$(Q) $(MAKE) $(MAKEPDIR) -C ./app flash
else
	$(Q) $(ESPTOOL) --port $(ESPPORT) write_flash 0x00000 $(FIRMWAREDIR)0x00000.bin 0x10000 $(FIRMWAREDIR)0x10000.bin
endif

.subdirs:
	$(Q) set -e; $(foreach d, $(SUBDIRS), $(MAKE) $(MAKEPDIR) -C $(d);)

bin/rboot.bin: rboot/firmware/rboot.bin
	$(Q) cp $^ $@

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(MAKECMDGOALS),clobber)
ifdef DEPS
sinclude $(DEPS)
endif
endif
endif

.PHONY: spiffs-image-remove

spiffs-image-remove:
	$(MAKE) -C tools remove-image

.PHONY: spiffs-image

spiffs-image: bin/0x10000.bin
	$(MAKE) -C tools

.PHONY: pre_build

ifneq ($(wildcard $(TOP_DIR)/server-ca.crt),)
pre_build: $(TOP_DIR)/app/modules/server-ca.crt.h

$(TOP_DIR)/app/modules/server-ca.crt.h: $(TOP_DIR)/server-ca.crt
	python $(TOP_DIR)/tools/make_server_cert.py $(TOP_DIR)/server-ca.crt > $(TOP_DIR)/app/modules/server-ca.crt.h

DEFINES += -DHAVE_SSL_SERVER_CRT=\"server-ca.crt.h\"
else
pre_build:
	@-rm -f $(TOP_DIR)/app/modules/server-ca.crt.h
endif


$(OBJODIR)/%.o: %.c
	$(Q) mkdir -p $(OBJODIR);
	$(QECHO) CC $<
	$(Q) $(CC) $(if $(findstring $<,$(DSRCS)),$(DFLAGS),$(CFLAGS)) $(COPTS_$(*F)) -o $@ -c $<

$(OBJODIR)/%.d: %.c
	$(Q) mkdir -p $(OBJODIR);
	$(VECHO) DEPEND: $(CC) -M $(CFLAGS) $<
	$(Q) set -e; rm -f $@; \
	$(CC) -M $(CFLAGS) $< > $@.$$$$; \
	sed 's,\($*\.o\)[ :]*,$(OBJODIR)/\1 $@ : ,g' < $@.$$$$ > $@; \
	rm -f $@.$$$$

$(OBJODIR)/%.o: %.s
	$(Q) mkdir -p $(OBJODIR);
	$(QECHO) CC $<
	$(Q) $(CC) $(CFLAGS) -o $@ -c $<

$(OBJODIR)/%.d: %.s
	$(Q) mkdir -p $(OBJODIR);
	$(Q) set -e; rm -f $@; \
	$(CC) -M $(CFLAGS) $< > $@.$$$$; \
	sed 's,\($*\.o\)[ :]*,$(OBJODIR)/\1 $@ : ,g' < $@.$$$$ > $@; \
	rm -f $@.$$$$

$(OBJODIR)/%.o: %.S
	$(Q) mkdir -p $(OBJODIR);
	$(QECHO) CC $<
	$(Q) $(CC) $(CFLAGS) -D__ASSEMBLER__ -o $@ -c $<

$(OBJODIR)/%.d: %.S
	$(Q) mkdir -p $(OBJODIR);
	$(QECHO) CC $<
	$(Q) set -e; rm -f $@; \
	$(CC) -M $(CFLAGS) $< > $@.$$$$; \
	sed 's,\($*\.o\)[ :]*,$(OBJODIR)/\1 $@ : ,g' < $@.$$$$ > $@; \
	rm -f $@.$$$$

$(foreach lib,$(GEN_LIBS),$(eval $(call ShortcutRule,$(lib),$(LIBODIR))))

$(foreach image,$(GEN_IMAGES),$(eval $(call ShortcutRule,$(image),$(IMAGEODIR))))

$(foreach bin,$(GEN_BINS),$(eval $(call ShortcutRule,$(bin),$(BINODIR))))

$(foreach lib,$(GEN_LIBS),$(eval $(call MakeLibrary,$(basename $(lib)))))

$(foreach image,$(GEN_IMAGES),$(eval $(call MakeImage,$(basename $(image)))))

#############################################################
# Recursion Magic - Don't touch this!!
#
# Each subtree potentially has an include directory
#   corresponding to the common APIs applicable to modules
#   rooted at that subtree. Accordingly, the INCLUDE PATH
#   of a module can only contain the include directories up
#   its parent path, and not its siblings
#
# Required for each makefile to inherit from the parent
#

INCLUDES := $(INCLUDES) -I $(PDIR)include -I $(PDIR)include/$(TARGET)
PDIR := ../$(PDIR)
sinclude $(PDIR)Makefile
