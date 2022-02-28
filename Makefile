#=======================================================================
# Makefile for Xcompact3D
#=======================================================================
# Choose pre-processing options
#   -DDOUBLE_PREC - use double-precision
#   -DSAVE_SINGLE - Save 3D data in single-precision
#   -DDEBG        - debuggin xcompact3d.f90
# generate a Git version string
GIT_VERSION := $(shell git describe --tag --long --always)
BUILD =

DEFS ?= -DDOUBLE_PREC

LCL = local# local,lad,sdu,archer
IVER = 17# 15,16,17,18
CMP = gcc# intel,gcc,nvhpc
FFT = generic# generic,fftw3,mkl

#######CMP settings###########
ifeq ($(CMP),intel)
	FC = mpiifort
	FFLAGS = -fpp -O3 -mavx2 -march=core-avx2 -mtune=core-avx2
	FFLAGS += -fopenmp
else ifeq ($(CMP),gcc)
	FC = mpif90
	FFLAGS = -cpp
	ifeq ($(BUILD), debug)
		FFLAGS += -g3 -Og
		FFLAGS += -ffpe-trap=invalid,zero
	else
		FFLAGS += -g -O3 -march=native
		FFLAGS += -funroll-loops -floop-optimize
	endif
	FFLAGS += -Warray-bounds -fcray-pointer -fbacktrace -ffree-line-length-none
	FFLAGS += -fopenmp -ftree-parallelize-loops=2
else ifeq ($(CMP),nagfor)
	FC = mpinagfor
	FFLAGS = -fpp
else ifeq ($(CMP),cray)
	FC = ftn
	FFLAGS = -eF -g -O3 -N 1023
else ifeq ($(CMP),nvhpc)
	FC = mpif90
	FFLAGS = -cpp -O3 -march=native
	#FFLAGS += -Minfo=accel -stdpar -acc -target=multicore
	FFLAGS = -cpp -Mfree -Kieee -Minfo=accel,ftn,inline,loop,vect,opt,stdpar -stdpar=gpu -gpu=cc70,managed,lineinfo -acc -target=gpu
endif

MODDIR = ./mod
DECOMPDIR = ./decomp2d
SRCDIR = ./src

### List of files for the main code
#SRC = $(SRCDIR)/x3d_precision.f90 $(SRCDIR)/module_param.f90 $(SRCDIR)/variables.f90 $(SRCDIR)/thomas.f90 $(SRCDIR)/poisson.f90 $(SRCDIR)/derive.f90 $(SRCDIR)/schemes.f90 $(SRCDIR)/parameters.f90 #$(SRCDIR)/*.f90
OBJ = $(SRC:%.f90=%.o)
SRC = $(SRCDIR)/x3d_precision.f90 $(SRCDIR)/module_param.f90 $(SRCDIR)/time_integrators.f90 $(SRCDIR)/x3d_transpose.f90 $(SRCDIR)/var.f90 $(SRCDIR)/thomas.f90 $(SRCDIR)/x3d_operator_x_data.f90 $(SRCDIR)/x3d_operator_y_data.f90 $(SRCDIR)/x3d_operator_z_data.f90 $(SRCDIR)/x3d_operator_1d.f90 $(SRCDIR)/poisson.f90 $(SRCDIR)/x3d_derive.f90 $(SRCDIR)/x3d_staggered.f90 $(SRCDIR)/x3d_filters.f90 $(SRCDIR)/navier.f90 $(SRCDIR)/parameters.f90 $(SRCDIR)/mom.f90 $(SRCDIR)/case.f90 $(SRCDIR)/transeq.f90 $(SRCDIR)/x3d_tools.f90 $(SRCDIR)/xcompact3d.f90

#######FFT settings##########
ifeq ($(FFT),fftw3)
  #FFTW3_PATH=/usr
  #FFTW3_PATH=/usr/lib64
  FFTW3_PATH=/usr/local/Cellar/fftw/3.3.7_1
  INC=-I$(FFTW3_PATH)/include
  LIBFFT=-L$(FFTW3_PATH) -lfftw3 -lfftw3f
else ifeq ($(FFT),fftw3_f03)
  FFTW3_PATH=/usr                                #ubuntu # apt install libfftw3-dev
  #FFTW3_PATH=/usr/lib64                         #fedora # dnf install fftw fftw-devel
  #FFTW3_PATH=/usr/local/Cellar/fftw/3.3.7_1     #macOS  # brew install fftw
  INC=-I$(FFTW3_PATH)/include
  LIBFFT=-L$(FFTW3_PATH)/lib -lfftw3 -lfftw3f
else ifeq ($(FFT),generic)
  INC=
  LIBFFT=#-lnvhpcwrapnvtx
else ifeq ($(FFT),mkl)
  SRCDECOMP := $(DECOMPDIR)/mkl_dfti.f90 $(SRCDECOMP)
  LIBFFT=-Wl,--start-group $(MKLROOT)/lib/intel64/libmkl_intel_lp64.a $(MKLROOT)/lib/intel64/libmkl_sequential.a $(MKLROOT)/lib/intel64/libmkl_core.a -Wl,--end-group -lpthread
	INC=-I$(MKLROOT)/include
endif

#######OPTIONS settings###########
OPT = -I$(SRCDIR) -I$(DECOMP_INCDIR) $(FFLAGS)
LINKOPT = $(FFLAGS) #-lnvhpcwrapnvtx

#-----------------------------------------------------------------------
# Normally no need to change anything below

DECOMP_LIB = 2decomp_fft
DECOMP_LIBDIR = $(DECOMPDIR)/lib
DECOMP_INCDIR = $(DECOMPDIR)/include
DECOMP.A = $(DECOMP_LIBDIR)/lib$(DECOMP_LIB).a
include $(DECOMPDIR)/src/Makefile.inc

DEFS += -DVERSION=\"$(GIT_VERSION)\"

all: xcompact3d

xcompact3d : $(DECOMP.A) $(OBJ)
	$(FC) -o $@ $(LINKOPT) $(OBJ) -L$(DECOMP_LIBDIR) -l$(DECOMP_LIB) $(LIBFFT)

$(DECOMP.A):
	make -C $(DECOMPDIR) F90=$(FC) OPTIONS="$(FFLAGS) $(DEFS) $(DEFS2)" lib

$(OBJ):$(SRCDIR)%.o : $(SRCDIR)%.f90
	$(FC) $(FFLAGS) $(OPT) $(DEFS) $(DEFS2) $(INC) -c $<
	mv $(@F) ${SRCDIR}
	#mv *.mod ${SRCDIR}

## This %.o : %.f90 doesn't appear to be called...
%.o : %.f90
	$(FC) $(FFLAGS) $(DEFS) $(DEFS2) $(INC) -c $<

.PHONY: post
post:
	$(FC) $(FFLAGS) $(DEFS) $(DEFS2) post.f90 -c
	$(FC) $(FFLAGS) -o $@ $(PSRC:.f90=.o)

.PHONY: clean


clean:
	rm -f $(SRCDIR)/*.o $(SRCDIR)/*.mod
	rm -f *.o *.mod xcompact3d post

.PHONY: clean-decomp
clean-decomp:
	make -C $(DECOMPDIR) clean

.PHONY: cleanall
cleanall: clean clean-decomp
	rm -f *~ \#*\# out/* data/* stats/* planes/* *.xdmf *.log *.out nodefile core sauve*
