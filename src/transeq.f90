!################################################################################
!This file is part of Xcompact3d.
!
!Xcompact3d
!Copyright (c) 2012 Eric Lamballais and Sylvain Laizet
!eric.lamballais@univ-poitiers.fr / sylvain.laizet@gmail.com
!
!    Xcompact3d is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation.
!
!    Xcompact3d is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with the code.  If not, see <http://www.gnu.org/licenses/>.
!-------------------------------------------------------------------------------
!-------------------------------------------------------------------------------
!    We kindly request that you cite Xcompact3d/Incompact3d in your
!    publications and presentations. The following citations are suggested:
!
!    1-Laizet S. & Lamballais E., 2009, High-order compact schemes for
!    incompressible flows: a simple and efficient method with the quasi-spectral
!    accuracy, J. Comp. Phys.,  vol 228 (15), pp 5989-6015
!
!    2-Laizet S. & Li N., 2011, Incompact3d: a powerful tool to tackle turbulence
!    problems with up to 0(10^5) computational cores, Int. J. of Numerical
!    Methods in Fluids, vol 67 (11), pp 1735-1757
!################################################################################
module transeq

  private
  public :: calculate_transeq_rhs

contains
  !############################################################################
  !!  SUBROUTINE: calculate_transeq_rhs
  !!      AUTHOR: Paul Bartholomew
  !! DESCRIPTION: Calculates the right hand sides of all transport
  !!              equations - momentum, scalar transport, etc.
  !############################################################################
  subroutine calculate_transeq_rhs(dux1,duy1,duz1,ux1,uy1,uz1)

    use decomp_2d, only : mytype
    use decomp_2d, only : xsize, zsize
    use param, only : ntime

    implicit none

    !! Inputs
    real(mytype), dimension(xsize(1), xsize(2), xsize(3)), intent(in) :: ux1, uy1, uz1

    !! Outputs
    real(mytype), dimension(xsize(1), xsize(2), xsize(3), ntime) :: dux1, duy1, duz1

    !! Momentum equations
    call momentum_rhs_eq(dux1,duy1,duz1,ux1,uy1,uz1)

  end subroutine calculate_transeq_rhs
  !############################################################################
  !############################################################################
  !!
  !!  subroutine: momentum_rhs_eq
  !!      AUTHOR: ?
  !!    MODIFIED: Kay Schäfer
  !! DESCRIPTION: Calculation of convective and diffusion terms of momentum
  !!              equation
  !!
  !############################################################################
  !############################################################################
  subroutine momentum_rhs_eq(dux1,duy1,duz1,ux1,uy1,uz1)

    use param
    use variables
    use x3d_operator_1d
    use decomp_2d, only : mytype
    use x3d_transpose
    use x3d_derive
    use decomp_2d , only : xsize, ysize, zsize
    use var, only : ta1,tb1,tc1,td1,te1,tf1,tg1,th1,ti1
    use var, only : ux2,uy2,uz2,ta2,tb2,tc2,td2,te2,tf2,tg2,th2,ti2,tj2
    use var, only : ux3,uy3,uz3,ta3,tb3,tc3,td3,te3,tf3,tg3,th3,ti3

    use mom, only : test_du, test_dv, test_dw
    
    implicit none

    !! INPUTS
    real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: ux1,uy1,uz1

    !! OUTPUTS
    real(mytype),dimension(xsize(1),xsize(2),xsize(3),ntime) :: dux1,duy1,duz1


    integer :: i,j,k,is

    !SKEW SYMMETRIC FORM
    !WORK X-PENCILS
    
    do concurrent (k=1:xsize(3), j=1:xsize(2), i=1:xsize(1))
      ta1(i,j,k) = ux1(i,j,k) * ux1(i,j,k)
      tb1(i,j,k) = ux1(i,j,k) * uy1(i,j,k)
      tc1(i,j,k) = ux1(i,j,k) * uz1(i,j,k)
    enddo

    call derx (tb1,ta1,sx,x3d_op_derxp,xsize(1),xsize(2),xsize(3))
    call derx_00_omp (tc1,ta1,sx,x3d_op_derxp,xsize(1),xsize(2),xsize(3))
    
    !FINAL SUM: DIFF TERMS + CONV TERMS
    do concurrent (k=1:xsize(3), j=1:xsize(2), i=1:xsize(1))
      dux1(i,j,k,1) = tb1(i,j,k) - tc1(i,j,k)
      duy1(i,j,k,1) = tb1(i,j,k)
      duz1(i,j,k,1) = tc1(i,j,k)
    enddo

  end subroutine momentum_rhs_eq
  !############################################################################
  !############################################################################
end module transeq
