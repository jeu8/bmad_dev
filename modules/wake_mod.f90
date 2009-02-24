module wake_mod

use bmad_struct
use bmad_interface
use multipole_mod, only: ab_multipole_kick

contains

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine zero_lr_wakes_in_lat (lat)
!
! Routine to zero the long range wake amplitudes for the elements that have
! long range wakes in a lattice.
!
! Modules needed:
!   use wake_mod
!
! Input:
!   lat -- Lat_struct: Lattice
!
! Output:
!   lat -- Lat_struct: Lattice
!     %ele(:) -- Lattice elements
!       %wake%lr(:)%norm_sin -> Set to zero
!       %wake%lr(:)%norm_cos -> Set to zero
!       %wake%lr(:)%skew_sin -> Set to zero
!       %wake%lr(:)%skew_cos -> Set to zero
!-       

subroutine zero_lr_wakes_in_lat (lat)

implicit none

type (lat_struct) lat
integer i

!

do i = 1, lat%n_ele_max
  if (.not. associated(lat%ele(i)%wake)) cycle
  lat%ele(i)%wake%lr%norm_sin = 0; lat%ele(i)%wake%lr%norm_cos = 0
  lat%ele(i)%wake%lr%skew_sin = 0; lat%ele(i)%wake%lr%skew_cos = 0
enddo

end subroutine zero_lr_wakes_in_lat

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine lr_wake_add_to (ele, s_ref, orbit, charge)
!
! Subroutine to add to the existing long-range wake the contribution from
! a passing (macro)particle.
!
! Modules needed:
!   use wake_mod
!
! Input:
!   ele     -- Ele_struct: Element with wakes.
!   s_ref   -- Real(rp): S position of the reference particle.
!   orbit   -- Coord_struct: Starting coords.
!   charge  -- Real(rp): Charge of passing (macro)particle.
!
! Output:
!   ele     -- Ele_struct: Element with wakes.
!     %wake%lr(:)%norm_sin -- Non-skew sin-like wake components.
!     %wake%lr(:)%norm_cos -- Non-skew cos-like wake components.
!     %wake%lr(:)%skew_sin -- Non-skew sin-like wake components.
!     %wake%lr(:)%skew_cos -- Non-skew cos-like wake components.
!+

subroutine lr_wake_add_to (ele, s_ref, orbit, charge)

type (ele_struct), target :: ele
type (coord_struct) orbit
type (lr_wake_struct), pointer :: lr

integer i
real(rp) charge, s_ref, ds, k, f_exp, ff, c, s, kx, ky
real(rp) c_a, s_a, kxx

! Check if we have to do any calculations

if (.not. bmad_com%lr_wakes_on) return  
if (.not. associated(ele%wake)) return
  
! Loop over all modes
! We use the following trick: The spatial variation of the normal and skew
! components is the same as the spatial variation of a multipole kick.

do i = 1, size(ele%wake%lr)

  lr => ele%wake%lr(i)
  ds = (s_ref + orbit%vec(5)) ! Note: ds < 0

  k = twopi * lr%freq / c_light
  f_exp = k / (2 * lr%Q)
  ff = charge * lr%r_over_q * c_light * exp(-ds * f_exp) / ele%value(p0c$) 

  c = cos (ds * k)
  s = sin (ds * k)

  call ab_multipole_kick (0.0_rp, ff, lr%m, orbit, kx, ky)

  if (lr%polarized) then
    c_a = cos(twopi*lr%angle); s_a = sin(twopi*lr%angle)
    kxx = kx
    kx = kxx * c_a * c_a + ky * s_a * c_a
    ky = kxx * c_a * s_a + ky * s_a * s_a
  endif

  lr%norm_sin = lr%norm_sin - kx * c
  lr%norm_cos = lr%norm_cos + kx * s
  lr%skew_sin = lr%skew_sin - ky * c
  lr%skew_cos = lr%skew_cos + ky * s

enddo

end subroutine

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine lr_wake_apply_kick (ele, s_ref, orbit)
!
! Subroutine to apply the long-range wake kick to a particle.
!
! Modules needed:
!   use wake_mod
!
! Input:
!   ele     -- Ele_struct: Element with wakes
!   s_ref   -- Real(rp): S position of the reference particle.
!   orbit   -- Coord_struct: Starting coords of the particle.
!
! Output:
!   orbit   -- Coord_struct: coords after the kick.
!+

subroutine lr_wake_apply_kick (ele, s_ref, orbit)

implicit none

type (ele_struct), target :: ele
type (coord_struct) orbit
type (lr_wake_struct), pointer :: lr

integer i
real(rp) s_ref, ds, k, f_exp, ff, c, s, w_norm, w_skew, kx, ky, k_dum

! Check if we have to do any calculations

if (.not. bmad_com%lr_wakes_on) return
if (.not. associated(ele%wake)) return

! Loop over all modes

do i = 1, size(ele%wake%lr)

  lr => ele%wake%lr(i)
  ds = s_ref + orbit%vec(5)  ! Note: ds < 0

  k = twopi * lr%freq / c_light
  f_exp = k / (2 * lr%Q)
  ff = exp(ds * f_exp)

  c = cos (ds * k)
  s = sin (ds * k)

! longitudinal kick

  w_norm = lr%norm_sin * ff * (f_exp * s + k * c) + &
           lr%norm_cos * ff * (f_exp * c - k * s)

  w_skew = lr%skew_sin * ff * (f_exp * s + k * c) + &
           lr%skew_cos * ff * (f_exp * c - k * s)

  call ab_multipole_kick (0.0_rp, w_norm, lr%m, orbit, kx, k_dum)
  call ab_multipole_kick (0.0_rp, w_skew, lr%m, orbit, k_dum, ky)

  orbit%vec(6) = orbit%vec(6) + kx + ky

! transverse kick

  if (lr%m == 0) cycle

  w_norm = lr%norm_sin * ff * s + lr%norm_cos * ff * c
  w_skew = lr%skew_sin * ff * s + lr%skew_cos * ff * c

  call ab_multipole_kick (w_skew, w_norm, lr%m-1, orbit, kx, ky)

  orbit%vec(2) = orbit%vec(2) - lr%m * kx
  orbit%vec(4) = orbit%vec(4) - lr%m * ky

enddo

end subroutine

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine sr_table_add_long_kick (ele, leader, charge, follower)
!
! Subroutine to add the component of the gradient loss from the leading particle
! on the following particle.
!
! Modules needed:
!   use wake_mod
!
! Input:
!   ele      -- Ele_struct: Element with wakes.
!   leader   -- Coord_struct: Coordinates of the leading particle.
!   charge   -- Real(rp): Charge of leader particle (in Coul).
!   follower -- Coord_struct: Starting coords of particle to kick.
!
! Output:
!   bmad_com%grad_loss_sr_wake -- Read(rp): adds the effects of the 
!                                  specified leader
!-

subroutine sr_table_add_long_kick (ele, leader, charge, follower)

implicit none

type (ele_struct) ele
type (coord_struct) leader, follower

real(rp) z, dz, f1, f2, charge, fact

integer iw, n_sr_table

if (.not. bmad_com%sr_wakes_on) return
if (.not. associated(ele%wake)) return

z = follower%vec(5) - leader%vec(5)
n_sr_table = size(ele%wake%sr_table) - 1
dz = ele%wake%sr_table(n_sr_table)%z / n_sr_table

iw = z / dz     ! integer part of z/dz
f2 = z/dz - iw  ! fractional part of z/dz
f1 = 1 - f2

if (iw .lt. 0 .or. iw .gt. ubound(ele%wake%sr_table,1)) return

bmad_com%grad_loss_sr_wake = bmad_com%grad_loss_sr_wake &
      + (ele%wake%sr_table(iw)%long*f1 + ele%wake%sr_table(iw+1)%long*f2) * charge 

end subroutine sr_table_add_long_kick

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine sr_table_apply_trans_kick (ele, leader, charge, follower)
!
! Subroutine to put in the transverse kick for the short-range wakes.
!
! Modules needed:
!   use wake_mod
!
! Input:
!   ele      -- Ele_struct: Element with wakes.
!   leader   -- Coord_struct: Coordinates of the leading particle.
!   charge   -- Real(rp): Charge of leader particle (in Coul).
!   follower -- Coord_struct: Starting coords of particle to kick.
!
! Output:
!   follower -- Coord_struct: coords after the kick.
!+

subroutine sr_table_apply_trans_kick (ele, leader, charge, follower)

implicit none

type (ele_struct) ele
type (coord_struct) leader, follower

real(rp) z, dz, f1, f2, charge, fact
integer iw, n_sr_table

!

if (.not. bmad_com%sr_wakes_on) return
if (.not. associated(ele%wake)) return

z = follower%vec(5) - leader%vec(5)
n_sr_table = size(ele%wake%sr_table) - 1
dz = ele%wake%sr_table(n_sr_table)%z / n_sr_table

iw = z / dz     ! integer part of z/dz
f2 = z/dz - iw  ! fractional part of z/dz
f1 = 1 - f2

fact = (ele%wake%sr_table(iw)%trans*f1 + ele%wake%sr_table(iw+1)%trans*f2) * &
                              charge * ele%value(l$) / ele%value(p0c$)
follower%vec(2) = follower%vec(2) - fact * leader%vec(1)
follower%vec(4) = follower%vec(4) - fact * leader%vec(3)

end subroutine

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine sr_mode_long_wake_add_to (ele, orbit, charge)
!
! Subroutine to add to the existing short-range wake the contribution from
! a passing (macro)particle.
!
! Modules needed:
!   use wake_mod
!
! Input:
!   ele     -- Ele_struct: Element with wakes.
!   orbit   -- Coord_struct: Starting coords.
!   charge  -- Real(rp): Charge of passing (macro)particle.
!
! Output:
!   ele     -- Ele_struct: Element with wakes.
!+

subroutine sr_mode_long_wake_add_to (ele, orbit, charge)

type (ele_struct), target :: ele
type (sr_mode_wake_struct), pointer :: sr_mode_long
type (coord_struct) orbit

integer i
real(rp) charge, arg, ff, c, s

! Check if we have to do any calculations

if (.not. bmad_com%sr_wakes_on) return
if (.not. associated(ele%wake)) return

! Add to wake
! The monipole wake does not have any skew components.

do i = 1, size(ele%wake%sr_mode_long)

  sr_mode_long => ele%wake%sr_mode_long(i)

  ff = charge * sr_mode_long%amp * exp(-orbit%vec(5) * sr_mode_long%damp) * &
                                          ele%value(l$) / ele%value(p0c$)

  arg = sr_mode_long%phi - orbit%vec(5) * sr_mode_long%k 
  c = cos (arg)
  s = sin (arg)

  sr_mode_long%norm_sin = sr_mode_long%norm_sin + ff * c
  sr_mode_long%norm_cos = sr_mode_long%norm_cos + ff * s

enddo

end subroutine

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine sr_mode_long_wake_apply_kick (ele, orbit)
!
! Subroutine to put in the kick for the short-range wakes.
!
! Modules needed:
!   use wake_mod
!
! Input:
!   ele     -- Ele_struct: Element with wakes
!   orbit   -- Coord_struct: Starting coords.
!
! Output:
!   orbit   -- Coord_struct: coords after the kick.
!+

subroutine sr_mode_long_wake_apply_kick (ele, orbit)

implicit none

type (ele_struct), target :: ele
type (coord_struct) orbit
type (sr_mode_wake_struct), pointer :: sr_mode_long

integer i
real(rp) arg, ff, c, s, w_norm

! Check if we have to do any calculations

if (.not. bmad_com%sr_wakes_on) return
if (.not. associated(ele%wake)) return

! Loop over all modes

do i = 1, size(ele%wake%sr_mode_long)

  sr_mode_long => ele%wake%sr_mode_long(i)

  ff = exp(orbit%vec(5) * sr_mode_long%damp)

  arg = orbit%vec(5) * sr_mode_long%k 
  c = cos (arg)
  s = sin (arg)

  w_norm = sr_mode_long%norm_sin * ff * s + sr_mode_long%norm_cos * ff * c
  orbit%vec(6) = orbit%vec(6) - w_norm

enddo

end subroutine

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine sr_mode_long_self_wake_apply_kick (ele, charge, orbit)
!
! Subroutine to put in the kick for the short-range wakes
!
! Modules needed:
!   use wake_mod
!
! Input:
!   ele     -- Ele_struct: Element with wakes
!   charge  -- Real(rp): Charge of passing (macro)particle.
!   orbit   -- Coord_struct: Starting coords.
!
! Output:
!   orbit   -- Coord_struct: coords after the kick.
!+

subroutine sr_mode_long_self_wake_apply_kick (ele, charge, orbit)

implicit none

type (ele_struct), target :: ele
type (coord_struct) orbit
type (sr_mode_wake_struct), pointer :: sr_mode_long

integer i
real(rp) k, c, s, w_norm, charge

! Check if we have to do any calculations

if (.not. bmad_com%sr_wakes_on) return
if (.not. associated(ele%wake)) return

! Loop over all modes

do i = 1, size(ele%wake%sr_mode_long)
  sr_mode_long => ele%wake%sr_mode_long(i)
  orbit%vec(6) = orbit%vec(6) - charge * sin(sr_mode_long%phi) * &
                         sr_mode_long%amp * ele%value(l$) / (2 * ele%value(p0c$))
enddo

end subroutine

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine sr_mode_trans_wake_add_to (ele, orbit, charge)
!
! Subroutine to add to the existing short-range wake the contribution from
! a passing (macro)particle.
!
! Modules needed:
!   use wake_mod
!
! Input:
!   ele     -- Ele_struct: Element with wakes.
!   orbit   -- Coord_struct: Starting coords.
!   charge  -- Real(rp): Charge of passing (macro)particle.
!
! Output:
!   ele     -- Ele_struct: Element with wakes.
!+

subroutine sr_mode_trans_wake_add_to (ele, orbit, charge)

type (ele_struct), target :: ele
type (sr_mode_wake_struct), pointer :: sr_mode_trans
type (coord_struct) orbit

integer i
real(rp) charge, arg, ff, c, s

! Check if we have to do any calculations

if (.not. bmad_com%sr_wakes_on) return  
if (.not. associated(ele%wake)) return

! Add to wake
! The monipole wake does not have any skew components.

do i = 1, size(ele%wake%sr_mode_trans)

  sr_mode_trans => ele%wake%sr_mode_trans(i)

  ff = charge * sr_mode_trans%amp * exp(-orbit%vec(5) * sr_mode_trans%damp) * &
                                           ele%value(l$) / ele%value(p0c$)

  arg =  sr_mode_trans%phi - orbit%vec(5) * sr_mode_trans%k 
  c = cos (arg)
  s = sin (arg)

  sr_mode_trans%norm_sin = sr_mode_trans%norm_sin + ff * orbit%vec(1) * c
  sr_mode_trans%norm_cos = sr_mode_trans%norm_cos + ff * orbit%vec(1) * s
  sr_mode_trans%skew_sin = sr_mode_trans%skew_sin + ff * orbit%vec(3) * c
  sr_mode_trans%skew_cos = sr_mode_trans%skew_cos + ff * orbit%vec(3) * s

enddo

end subroutine

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine sr_mode_trans_wake_apply_kick (ele, orbit)
!
! Subroutine to put in the kick for the short-range wakes
!
! Modules needed:
!   use wake_mod
!
! Input:
!   ele     -- Ele_struct: Element with wakes
!   orbit   -- Coord_struct: Starting coords.
!
! Output:
!   orbit   -- Coord_struct: coords after the kick.
!+

subroutine sr_mode_trans_wake_apply_kick (ele, orbit)

implicit none

type (ele_struct), target :: ele
type (coord_struct) orbit
type (sr_mode_wake_struct), pointer :: sr_mode_trans

integer i
real(rp) arg, ff, c, s, w_norm, w_skew

! Check if we have to do any calculations

if (.not. bmad_com%sr_wakes_on) return
if (.not. associated(ele%wake)) return

! Loop over all modes

do i = 1, size(ele%wake%sr_mode_trans)

  sr_mode_trans => ele%wake%sr_mode_trans(i)

  ff = exp(orbit%vec(5) * sr_mode_trans%damp)

  arg = orbit%vec(5) * sr_mode_trans%k 
  c = cos (arg)
  s = sin (arg)

  w_norm = sr_mode_trans%norm_sin * ff * s + sr_mode_trans%norm_cos * ff * c
  w_skew = sr_mode_trans%skew_sin * ff * s + sr_mode_trans%skew_cos * ff * c

  orbit%vec(2) = orbit%vec(2) - w_norm
  orbit%vec(4) = orbit%vec(4) - w_skew

enddo

end subroutine

end module
