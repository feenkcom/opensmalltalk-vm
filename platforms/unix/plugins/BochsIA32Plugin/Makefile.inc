XCFLAGS=-m32
XCPPFLAGS=	-m32 -DUSE_BOCHS_CONFIG_H=1 \
			-I../../../bochsx32 \
			-I$(topdir)/processors/IA32/bochs \
			-I$(topdir)/processors/IA32/bochs/instrument/stubs

XLDFLAGS=	-L../../../bochsx32/cpu \
			-L../../../bochsx32/fpu \
			-L../../../bochsx32/disasm \
			-lcpu -lfpu -ldisasm \
			-lstdc++