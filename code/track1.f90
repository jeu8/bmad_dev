!+
! Subroutine track1 (start, ele, param, end, track)
!
! Particle tracking through a single element. 
! Optionally synchrotron radiation and space charge kicks can included.
!
! Modules Needed:
!   use bmad
!
! Input:
!   start  -- Coord_struct: Starting position.
!   ele    -- Ele_struct: Element to track through.
!   param  -- lat_param_struct:
!     %aperture_limit_on -- If True check if particle is lost by going outside
!                of the element aperture. 
!
! Output:
!   end   -- Coord_struct: End position.
!   param
!     %lost          -- Set True If the particle cannot make it through an element.
!                         Set False otherwise.
!     %plane_lost_at -- x_plane$, y_plane$ (for apertures), or 
!                         z_plane$ (turned around in an lcavity).
!     %end_lost_at   -- entrance_end$ or exit_end$.
!   track -- track_struct, optional: Structure holding the track information if the 
!             tracking method does tracking step-by-step.
!
! Notes:
! It is assumed that HKICK and VKICK are the kicks in the horizontal
! and vertical kicks irregardless of the value for TILT.
!-

subroutine track1 (start, ele, param, end, track)

use bmad, except_dummy1 => track1
use mad_mod, only: track1_mad
use boris_mod, only: track1_boris, track1_adaptive_boris
use space_charge_mod, except_dummy2 => track1
use spin_mod, except_dummy3 => track1

implicit none

type (coord_struct) :: start
type (coord_struct) :: end
type (coord_struct) :: orb
type (ele_struct)   :: ele
type (lat_param_struct) :: param
type (track_struct), optional :: track

real(rp) beta, beta_start

integer tracking_method

character(8), parameter :: r_name = 'track1'

! Custom tracking

tracking_method = ele%tracking_method

if (tracking_method == custom$) then
  call track1_custom (start, ele, param, end, track)
  return
endif

! Init

param%lost = .false.  ! assume everything will be OK
param%ix_lost = not_lost$

if (bmad_com%auto_bookkeeper) call attribute_bookkeeper (ele, param)

! check for particles outside aperture

if (ele%aperture_at == entrance_end$ .or. ele%aperture_at == both_ends$ .or. ele%aperture_at == continuous$) &
                call check_aperture_limit (start, ele, entrance_end$, param)
if (param%lost) then
  param%end_lost_at = entrance_end$
  param%ix_lost = ele%ix_ele
  call init_coord (end)      ! it never got to the end so zero this.
  return
endif

! Radiation damping and/or fluctuations for the 1st half of the element.

if ((bmad_com%radiation_damping_on .or. &
            bmad_com%radiation_fluctuations_on) .and. ele%is_on) then
  call track1_radiation (start, ele, param, orb, start_edge$) 
else
  orb = start
endif

! bmad_standard handles the case when the element is turned off.

if (.not. ele%is_on) tracking_method = bmad_standard$

select case (tracking_method)

case (bmad_standard$) 
  call track1_bmad (orb, ele, param, end)

case (runge_kutta$) 
  call track1_runge_kutta (orb, ele, param, end, track)

case (linear$) 
  call track1_linear (orb, ele, param, end)

case (taylor$) 
  call track1_taylor (orb, ele, param, end)

case (symp_map$) 
  call track1_symp_map (orb, ele, param, end)

case (symp_lie_bmad$) 
  call symp_lie_bmad (ele, param, orb, end, .false., track)

case (symp_lie_ptc$) 
  call track1_symp_lie_ptc (orb, ele, param, end)

case (adaptive_boris$) 
  call track1_adaptive_boris (orb, ele, param, end, track)

case (boris$) 
  call track1_boris (orb, ele, param, end, track)

case (mad$)
  call track1_mad (orb, ele, param, end)

case (time_runge_kutta$)
  call track1_time_runge_kutta (orb, ele, param, end, track)

case default
  call out_io (s_fatal$, r_name, 'UNKNOWN TRACKING_METHOD: \i0\ ', ele%tracking_method)
  call err_exit

end select

! s and time update

end%s = ele%s

if (ele%key == lcavity$ .or. ele%key == custom$) then
  call convert_pc_to (ele%value(p0c$) * (1 + end%vec(6)), param%particle, beta = beta)
  call convert_pc_to (ele%value(p0c_start$) * (1 + start%vec(6)), param%particle, beta = beta_start)
  end%t = start%t + ele%value(delta_ref_time$) + &
                          start%vec(5) / (beta_start * c_light) - end%vec(5) / (beta * c_light)
else
  call convert_pc_to (ele%value(p0c$) * (1 + end%vec(6)), param%particle, beta = beta)
  end%t = start%t + ele%value(delta_ref_time$) + (start%vec(5) - end%vec(5)) / (beta * c_light)
endif

! Radiation damping and/or fluctuations for the last half of the element

if ((bmad_com%radiation_damping_on .or. &
                  bmad_com%radiation_fluctuations_on) .and. ele%is_on) then
  call track1_radiation (end, ele, param, end, end_edge$) 
endif

! space charge

if (bmad_com%space_charge_on) &
      call track1_ultra_rel_space_charge (end, ele, param, end)

! spin tracking
 
if (bmad_com%spin_tracking_on) call track1_spin (orb, ele, param, end)

! check for particles outside aperture

if (.not. param%lost) then
  if (ele%aperture_at == exit_end$ .or. ele%aperture_at == both_ends$ .or. ele%aperture_at == continuous$) then
    call check_aperture_limit (end, ele, exit_end$, param)
    if (param%lost) param%end_lost_at = exit_end$
  endif
endif

if (param%lost .and. param%end_lost_at == live_reversed$) then
  param%lost = .false. ! Temp
  if (ele%aperture_at == entrance_end$ .or. ele%aperture_at == both_ends$ .or. ele%aperture_at == continuous$) &
                  call check_aperture_limit (start, ele, entrance_end$, param)
  if (param%lost) then
    param%end_lost_at = entrance_end$
    param%ix_lost = ele%ix_ele
    call init_coord (end)      ! it never got to the end so zero this.
    return
  endif
  param%lost = .true.
endif

if (param%lost) then
  param%ix_lost = ele%ix_ele
  return
endif

end subroutine
