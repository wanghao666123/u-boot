#
# (C) Copyright 2000-2006
# Wolfgang Denk, DENX Software Engineering, wd@denx.de.
#
# See file CREDITS for list of people who contributed to this
# project.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA 02111-1307 USA
#

#########################################################################
#!OBJTREE和SRCTREE路径相等，所以下面不会执行
ifneq ($(OBJTREE),$(SRCTREE))
ifeq ($(CURDIR),$(SRCTREE))
dir :=
else
dir := $(subst $(SRCTREE)/,,$(CURDIR))#!会将$(CURDIR)中出现的$(SRCTREE)/替换成空字符串
endif

obj := $(if $(dir),$(OBJTREE)/$(dir)/,$(OBJTREE)/)#!obj = $(OBJTREE)
src := $(if $(dir),$(SRCTREE)/$(dir)/,$(SRCTREE)/)#!src = $(SRCTREE)

$(shell mkdir -p $(obj))
else
obj := 
src :=
endif
#!最终obj和src都为空
# clean the slate ...
PLATFORM_RELFLAGS =
PLATFORM_CPPFLAGS =
PLATFORM_LDFLAGS =

#########################################################################
#!HOSTOS = linux
ifeq ($(HOSTOS),darwin)
HOSTCC		= cc
else
HOSTCC		= gcc
endif
#!HOSTCC = gcc
#!-Wall：启用所有常见的编译警告。使用这个选项可以帮助开发者发现代码中的潜在问题或非最佳实践的用法。
#!-Wstrict-prototypes：要求在 C 函数声明中使用严格的原型声明。如果函数的参数类型不明确，它会发出警告。这对于提高代码的类型安全性和可读性很有帮助。
#!-O2：启用编译器的优化等级 2。在这个优化级别，编译器会对代码进行相当多的优化，以提高生成代码的执行效率，但不会像更高级别（例如 -O3）那样激进，以保持合理的编译时间和代码大小。
#!-fomit-frame-pointer：告诉编译器在生成的代码中省略帧指针（frame pointer）。省略帧指针可以让编译器更自由地使用寄存器，从而提高代码的性能，但在调试时可能会让栈回溯变得更困难。
HOSTCFLAGS	= -Wall -Wstrict-prototypes -O2 -fomit-frame-pointer
HOSTSTRIP	= strip

#########################################################################
#
# Option checker (courtesy linux kernel) to ensure
# only supported compiler options are used
#
#!根据指定的编译选项，检查编译器是否支持该选项。如果支持，它会返回该选项；如果不支持，它会返回一个替代选项或空字符串
cc-option = $(shell if $(CC) $(CFLAGS) $(1) -S -o /dev/null -xc /dev/null \
		> /dev/null 2>&1; then echo "$(1)"; else echo "$(2)"; fi ;)

#
# Include the make variables (CC, etc...)
#
#!CROSS_COMPILE为空
AS	= $(CROSS_COMPILE)as
LD	= $(CROSS_COMPILE)ld
CC	= $(CROSS_COMPILE)gcc
CPP	= $(CC) -E
AR	= $(CROSS_COMPILE)ar
NM	= $(CROSS_COMPILE)nm
LDR	= $(CROSS_COMPILE)ldr
STRIP	= $(CROSS_COMPILE)strip
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump
RANLIB	= $(CROSS_COMPILE)RANLIB

#########################################################################

# Load generated board configuration
sinclude $(OBJTREE)/include/autoconf.mk

ifdef	ARCH
sinclude $(TOPDIR)/lib_$(ARCH)/config.mk	# include architecture dependend rules
endif
ifdef	CPU
sinclude $(TOPDIR)/cpu/$(CPU)/config.mk		# include  CPU	specific rules
endif
ifdef	SOC
sinclude $(TOPDIR)/cpu/$(CPU)/$(SOC)/config.mk	# include  SoC	specific rules
endif
ifdef	VENDOR
BOARDDIR = $(VENDOR)/$(BOARD) #!BOARDDIR = samsung/smdk2410
else
BOARDDIR = $(BOARD)
endif
ifdef	BOARD
sinclude $(TOPDIR)/board/$(BOARDDIR)/config.mk	# include board specific rules   TEXT_BASE = 0x33F80000
endif

#########################################################################

ifneq (,$(findstring s,$(MAKEFLAGS)))
ARFLAGS = cr
else
ARFLAGS = crv
endif
RELFLAGS= $(PLATFORM_RELFLAGS) #! 为空
DBGFLAGS= -g #!-DDEBUG -g：告诉编译器在生成目标文件时包含调试信息。这样，调试工具（如 GDB）就可以使用这些信息来帮助开发人员定位代码中的问题。
OPTFLAGS= -Os #!-fomit-frame-pointer  -Os：是一个编译器优化选项，它的作用是优化代码以减小最终生成的可执行文件的大小，同时尽量保持执行速度不显著降低。它是一个介于 -O2 和 -O3 之间的优化级别，但优先考虑减少代码体积。
ifndef LDSCRIPT
#LDSCRIPT := $(TOPDIR)/board/$(BOARDDIR)/u-boot.lds.debug
ifeq ($(CONFIG_NAND_U_BOOT),y)
LDSCRIPT := $(TOPDIR)/board/$(BOARDDIR)/u-boot-nand.lds
else
LDSCRIPT := $(TOPDIR)/board/$(BOARDDIR)/u-boot.lds  #!在samsung/smdk2410下没找到
endif
endif
#!这个选项告诉 objcopy 在目标文件的填充区域（通常是由于对齐要求而插入的空白区域）填充特定的字节值。在这个例子中，填充的字节值是 0xff，即十六进制的255。
OBJCFLAGS += --gap-fill=0xff
#!gccincdir 将包含 GCC 标准头文件的路径，例如 /usr/include 或 /usr/local/include，具体取决于 GCC 的安装和配置
gccincdir := $(shell $(CC) -print-file-name=include)

#! __KERNEL__：这是一个常用的宏，通常在 Linux 内核或其他与内核相关的代码中用来指示当前编译环境是为内核模块或内核空间编译的。
CPPFLAGS := $(DBGFLAGS) $(OPTFLAGS) $(RELFLAGS)		\
	-D__KERNEL__
#!CPPFLAGS = -g -Os -D__KERNEL__
ifneq ($(TEXT_BASE),)
CPPFLAGS += -DTEXT_BASE=$(TEXT_BASE) #! -DTEXT_BASE=$(TEXT_BASE) ===>>> #define TEXT_BASE $(TEXT_BASE)
endif
#!CPPFLAGS = -g -Os -D__KERNEL__
ifneq ($(RESET_VECTOR_ADDRESS),)
CPPFLAGS += -DRESET_VECTOR_ADDRESS=$(RESET_VECTOR_ADDRESS) #! #define RESET_VECTOR_ADDRESS $(RESET_VECTOR_ADDRESS)
endif
#!CPPFLAGS = -g -Os -D__KERNEL__
#!-I 选项用于指定编译器的头文件搜索路径。
ifneq ($(OBJTREE),$(SRCTREE))
CPPFLAGS += -I$(OBJTREE)/include2 -I$(OBJTREE)/include
endif
#!CPPFLAGS = -g -Os -D__KERNEL__
CPPFLAGS += -I$(TOPDIR)/include
#!CPPFLAGS = -g -Os -D__KERNEL__ -I$(TOPDIR)/include
#!-fno-builtin：禁用编译器内置函数的优化。这意味着编译器不会假设某些函数（例如 memcpy、printf 等）是优化的版本，而是会按照用户提供的实现来编译。这通常在嵌入式开发或操作系统开发中使用，因为开发者希望完全控制代码的行为
#!-ffreestanding：表示程序不依赖于标准库的实现。这通常用于操作系统内核开发或某些嵌入式系统，意味着代码可能不使用任何标准库提供的功能。
#!-nostdinc：告诉编译器不自动搜索标准系统头文件。这是因为在某些情况下，程序可能使用自定义的头文件而不需要标准库的定义。
#!-isystem $(gccincdir)：该选项用于指定一个系统头文件目录。$(gccincdir) 是一个变量，通常包含了 GCC 的系统头文件路径。在这里，编译器会在这个路径下查找头文件，并把它们当作系统头文件来处理，可能会影响警告的显示。
#!-pipe：使用管道而不是临时文件来进行编译过程中的进程间通信。这通常会加快编译速度，尤其是在处理多个源文件时。
#!PLATFORM_CPPFLAGS为空
CPPFLAGS += -fno-builtin -ffreestanding -nostdinc	\
	-isystem $(gccincdir) -pipe $(PLATFORM_CPPFLAGS)
#!CPPFLAGS = -g -Os -D__KERNEL__ -I$(TOPDIR)/include -fno-builtin -ffreestanding -nostdinc -isystem $(gccincdir)

ifdef BUILD_TAG
CFLAGS := $(CPPFLAGS) -Wall -Wstrict-prototypes \
	-DBUILD_TAG='"$(BUILD_TAG)"'
else
CFLAGS := $(CPPFLAGS) -Wall -Wstrict-prototypes
endif

CFLAGS += $(call cc-option,-fno-stack-protector)

# avoid trigraph warnings while parsing pci.h (produced by NIOS gcc-2.9)
# this option have to be placed behind -Wall -- that's why it is here
ifeq ($(ARCH),nios)
ifeq ($(findstring 2.9,$(shell $(CC) --version)),2.9)
CFLAGS := $(CPPFLAGS) -Wall -Wno-trigraphs
endif
endif

# $(CPPFLAGS) sets -g, which causes gcc to pass a suitable -g<format>
# option to the assembler.
AFLAGS_DEBUG :=

# turn jbsr into jsr for m68k
ifeq ($(ARCH),m68k)
ifeq ($(findstring 3.4,$(shell $(CC) --version)),3.4)
AFLAGS_DEBUG := -Wa,-gstabs,-S
endif
endif

AFLAGS := $(AFLAGS_DEBUG) -D__ASSEMBLY__ $(CPPFLAGS)

LDFLAGS += -Bstatic -T $(obj)u-boot.lds $(PLATFORM_LDFLAGS)
ifneq ($(TEXT_BASE),)
LDFLAGS += -Ttext $(TEXT_BASE)
endif

# Location of a usable BFD library, where we define "usable" as
# "built for ${HOST}, supports ${TARGET}".  Sensible values are
# - When cross-compiling: the root of the cross-environment
# - Linux/ppc (native): /usr
# - NetBSD/ppc (native): you lose ... (must extract these from the
#   binutils build directory, plus the native and U-Boot include
#   files don't like each other)
#
# So far, this is used only by tools/gdb/Makefile.

ifeq ($(HOSTOS),darwin)
BFD_ROOT_DIR =		/usr/local/tools
else
ifeq ($(HOSTARCH),$(ARCH))
# native
BFD_ROOT_DIR =		/usr
else
#BFD_ROOT_DIR =		/LinuxPPC/CDK		# Linux/i386
#BFD_ROOT_DIR =		/usr/pkg/cross		# NetBSD/i386
BFD_ROOT_DIR =		/opt/powerpc
endif
endif

#########################################################################

export	HOSTCC HOSTCFLAGS CROSS_COMPILE \
	AS LD CC CPP AR NM STRIP OBJCOPY OBJDUMP MAKE
export	TEXT_BASE PLATFORM_CPPFLAGS PLATFORM_RELFLAGS CPPFLAGS CFLAGS AFLAGS

#########################################################################

# Allow boards to use custom optimize flags on a per dir/file basis
BCURDIR := $(notdir $(CURDIR))
$(obj)%.s:	%.S
	$(CPP) $(AFLAGS) $(AFLAGS_$(@F)) $(AFLAGS_$(BCURDIR)) -o $@ $<
$(obj)%.o:	%.S
	$(CC)  $(AFLAGS) $(AFLAGS_$(@F)) $(AFLAGS_$(BCURDIR)) -o $@ $< -c
$(obj)%.o:	%.c
	$(CC)  $(CFLAGS) $(CFLAGS_$(@F)) $(CFLAGS_$(BCURDIR)) -o $@ $< -c
$(obj)%.i:	%.c
	$(CPP) $(CFLAGS) $(CFLAGS_$(@F)) $(CFLAGS_$(BCURDIR)) -o $@ $< -c
$(obj)%.s:	%.c
	$(CC)  $(CFLAGS) $(CFLAGS_$(@F)) $(CFLAGS_$(BCURDIR)) -o $@ $< -c -S

#########################################################################
