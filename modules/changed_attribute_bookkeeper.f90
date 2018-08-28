module changed_attribute_bookkeeper

use equal_mod
use pointer_to_branch_mod

implicit none

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine set_flags_for_changed_attribute (...)
!
! Routine to mark an element or lattice as modified for use with "intelligent" bookkeeping.
! Also will do some dependent variable bookkeeping when a particular attribute has 
! been altered.
!
! This routine should be called after the attribute has been set.
!
! set_flags_for_changed_attribute is an overloaded name for:
!   set_flags_for_changed_lat_attribute (lat, set_dependent)
!   set_flags_for_changed_real_attribute (ele, real_attrib, set_dependent)
!   set_flags_for_changed_inteter_attribute (ele, int_attrib, set_dependent)
!   set_flags_for_changed_logical_attribute (ele, logic_attrib, set_dependent)
!   set_flags_for_changed_all_attribute (ele, all_attrib, set_dependent)
!
! The set_flags_for_changed_lat_attribute (lat) routine is used when one
! does not know what has changed and wants a complete bookkeeping done.
!
! NOTE: The attribute argument MUST be the component that was changed. For example:
!     ele%value(x_offset$) = off_value
!     call set_flags_for_changed_attribute (ele, ele%value(x_offset$))
! And NOT:
!     call set_flags_for_changed_attribute (ele, off_value)  ! WRONG
!
! Input:
!   lat           -- lat_struct: Lattice being modified.
!   ele           -- ele_struct, Element being modified.
!   real_attrib   -- real(rp), optional: Attribute that has been changed.
!                      For example: ele%value(hkick$).
!                      If not present then assume everything has potentially changed.
!   int_attrib    -- integer: Attribute that has been changed.
!                      For example: ele%mat6_calc_method.
!   logic_attrib  -- logical; Attribute that has been changed.
!                      For example: ele%is_on.
!   all_attrib    -- all_pointer_struct: Pointer to attribute.
!   set_dependent -- logical, optional: If False then dependent variable bookkeeping will not be done.
!                     Default is True. Do not set False unless you know what you are doing.
!
! Output:
!   lat  -- lat_struct: Lattice with appropriate changes.
!-

interface set_flags_for_changed_attribute
  module procedure set_flags_for_changed_real_attribute 
  module procedure set_flags_for_changed_integer_attribute 
  module procedure set_flags_for_changed_logical_attribute 
  module procedure set_flags_for_changed_all_attribute 
  module procedure set_flags_for_changed_lat_attribute 
end interface

contains

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine set_flags_for_changed_all_attribute (ele, all_attrib, set_dependent)
!
! Routine to mark an element as modified for use with "intelligent" bookkeeping.
!
! This routine is overloaded by set_flags_for_changed_attribute. 
! See set_flags_for_changed_attribute for more details.
!-

subroutine set_flags_for_changed_all_attribute (ele, all_attrib, set_dependent)

type (ele_struct), target :: ele
type (all_pointer_struct) all_attrib
logical, optional :: set_dependent

!

if (associated(all_attrib%r)) call set_flags_for_changed_real_attribute(ele, all_attrib%r, set_dependent)
if (associated(all_attrib%i)) call set_flags_for_changed_integer_attribute(ele, all_attrib%i, set_dependent)
if (associated(all_attrib%l)) call set_flags_for_changed_logical_attribute(ele, all_attrib%l, set_dependent)

end subroutine set_flags_for_changed_all_attribute

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine set_flags_for_changed_integer_attribute (ele, attrib, set_dependent)
!
! Routine to mark an element as modified for use with "intelligent" bookkeeping.
!
! This routine is overloaded by set_flags_for_changed_attribute. 
! See set_flags_for_changed_attribute for more details.
!-

subroutine set_flags_for_changed_integer_attribute (ele, attrib, set_dependent)

type (ele_struct), target :: ele
type (ele_struct), pointer :: slave

integer, target :: attrib
integer, pointer :: a_ptr
integer i

real(rp) dummy

logical, optional :: set_dependent

! This will set some generic flags

call set_flags_for_changed_real_attribute (ele, dummy, set_dependent)

!

a_ptr => attrib

select case (ele%key)
case (rfcavity$, lcavity$, e_gun$)
  if (associated(a_ptr, ele%tracking_method) .or. associated(a_ptr, ele%field_calc)) then
    call set_ele_status_stale (ele, ref_energy_group$)
  endif
end select

! Set independent stuff in multipass lord

if (ele%lord_status == multipass_lord$) then 

  do i = 1, ele%n_slave
    slave => pointer_to_slave(ele, i)
  
    if (associated(a_ptr, ele%aperture_at)) then
      slave%aperture_at = a_ptr
    elseif (associated(a_ptr, ele%aperture_type)) then
      ele%aperture_type = a_ptr
    elseif (associated(a_ptr, ele%mat6_calc_method)) then
      ele%mat6_calc_method = a_ptr
    elseif (associated(a_ptr, ele%tracking_method)) then
      ele%tracking_method = a_ptr
    elseif (associated(a_ptr, ele%spin_tracking_method)) then
      ele%spin_tracking_method = a_ptr
    elseif (associated(a_ptr, ele%field_calc)) then
      ele%field_calc = a_ptr
    else
      exit
    endif
  enddo

endif

end subroutine set_flags_for_changed_integer_attribute

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine set_flags_for_changed_logical_attribute (ele, attrib, set_dependent)
!
! Routine to mark an element as modified for use with "intelligent" bookkeeping.
!
! This routine is overloaded by set_flags_for_changed_attribute. 
! See set_flags_for_changed_attribute for more details.
!-

subroutine set_flags_for_changed_logical_attribute (ele, attrib, set_dependent)

type (ele_struct), target :: ele
type (ele_struct), pointer :: slave

integer i

real(rp) dummy

logical, target :: attrib
logical, pointer :: a_ptr
logical, optional :: set_dependent

! Call to set_flags_for_changed_real_attribute will set some generic flags

call set_flags_for_changed_real_attribute (ele, dummy, set_dependent)

a_ptr => attrib

! Set independent stuff in multipass lord

if (ele%lord_status == multipass_lord$) then 

  do i = 1, ele%n_slave
    slave => pointer_to_slave(ele, i)
  
    if (associated(a_ptr, ele%offset_moves_aperture)) then
      slave%offset_moves_aperture = attrib
    else
      exit
    endif
  enddo

endif

end subroutine set_flags_for_changed_logical_attribute

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine set_flags_for_changed_lat_attribute (lat, set_dependent)
!
! Routine to mark a lattice as modified for use with "intelligent" bookkeeping.
!
! This routine is overloaded by set_flags_for_changed_attribute. 
! See set_flags_for_changed_attribute for more details.
!-

subroutine set_flags_for_changed_lat_attribute (lat, set_dependent)

type (lat_struct), target :: lat
type (branch_struct), pointer :: branch

integer i, j
logical, optional :: set_dependent

!

do i = 0, ubound(lat%branch, 1)
  branch => lat%branch(i)
  call set_status_flags (branch%param%bookkeeping_state, stale$)
  do j = 0, ubound(branch%ele, 1)
    call set_status_flags (branch%ele(j)%bookkeeping_state, stale$)
  enddo
enddo

end subroutine set_flags_for_changed_lat_attribute

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine set_flags_for_changed_real_attribute (ele, attrib, set_dependent)
!
! Routine to mark an element as modified for use with "intelligent" bookkeeping.
!
! This routine is overloaded by set_flags_for_changed_attribute. 
! See set_flags_for_changed_attribute for more details.
!-

subroutine set_flags_for_changed_real_attribute (ele, attrib, set_dependent)

type (ele_struct), target :: ele
type (branch_struct), pointer :: branch
type (grid_field_struct), pointer :: g_field
type (cylindrical_map_struct), pointer :: cl_map

real(rp), optional, target :: attrib
real(rp), pointer :: a_ptr
real(rp) v_mat(4,4), v_inv_mat(4,4), eta_vec(4), eta_xy_vec(4)
real(rp), target :: unknown_attrib

integer i

logical coupling_change, found, dep_set
logical, optional :: set_dependent

!-------------------
! For a particular elemement...

branch => pointer_to_branch(ele)
dep_set = logic_option(.true., set_dependent)

! If a lord then set the control flag stale

if (ele%lord_status /= not_a_lord$) call set_ele_status_stale (ele, control_group$)

! Groups and overlays do not have any dependent attributes. 
! For all others set the attributes flag stale.

if (ele%key /= group$ .and. ele%key /= overlay$ .and. dep_set) then
  call set_ele_status_stale (ele, attribute_group$)
endif

! Transfer matrix calc needs to be flagged

if (ele%key /= overlay$ .and. ele%key /= group$ .and. &
    ele%lord_status /= multipass_lord$) then
  call set_ele_status_stale (ele, mat6_group$)
endif

! If attrib is not present then point to a dummy location which will not match when 
! the associated() function is used below.

if (.not. present(attrib)) then
  call set_ele_status_stale (ele, all_groups$)
endif

! Use a_ptr with the associated function to see which attribute has been changed.

a_ptr => attrib

! A limit change does not need any bookkeeping

if (associated(a_ptr, ele%value(x1_limit$)) .or. associated(a_ptr, ele%value(x2_limit$)) .or. &
    associated(a_ptr, ele%value(y1_limit$)) .or. associated(a_ptr, ele%value(y2_limit$))) return

! delta_ref_time change

if (associated(a_ptr, ele%value(delta_ref_time$))) then
  call set_ele_status_stale (ele, ref_energy_group$)  ! Energy & time
endif

! A length change involves changes in the floor position.

if (associated(a_ptr, ele%value(l$))) then
  if (ele%key /= overlay$ .and. ele%key /= group$) then
    call set_ele_status_stale (ele, s_and_floor_position_group$)
    call set_ele_status_stale (ele, floor_position_group$)
    call set_ele_status_stale (ele, ref_energy_group$)
  endif
  if (ele%value(p0c$) /= ele%value(p0c_start$)) call set_ele_status_stale (ele, ref_energy_group$)
  return
endif

! E_tot and p0c can be varied in an init_ele or a multipass lord with n_ref_pass = 0.
! In addition, for an init_ele, must also set e_tot_start and p0c_start. This is important
! for lattices with an e_gun element

if (associated(a_ptr, ele%value(e_tot$)) .and. associated(branch)) then
  select case (ele%key)
  case (lcavity$, rfcavity$, e_gun$, em_field$)
    call set_ele_status_stale (ele, ref_energy_group$, .true.)
  case default
    ! Lord energy is set from slave. Not other way around.
    call set_ele_status_stale (ele, ref_energy_group$, .false.)
  end select

  if (dep_set) then
    call convert_total_energy_to (ele%value(e_tot$), branch%param%particle, pc = ele%value(p0c$))
    if (ele%key == beginning_ele$) then
      ele%value(e_tot_start$) = ele%value(e_tot$)
      ele%value(p0c_start$) = ele%value(p0c$)
    endif
  endif
  return
endif

if (associated(a_ptr, ele%value(p0c$)) .and. associated(branch)) then
  select case (ele%key)
  case (lcavity$, rfcavity$, e_gun$, em_field$)
    call set_ele_status_stale (ele, ref_energy_group$, .true.)
  case default
    ! Lord energy is set from slave. Not other way around.
    call set_ele_status_stale (ele, ref_energy_group$, .false.)
  end select

  if (dep_set) then
    call convert_pc_to (ele%value(p0c$), branch%param%particle, e_tot = ele%value(e_tot$))
    if (ele%key == beginning_ele$) then
      ele%value(e_tot_start$) = ele%value(e_tot$)
      ele%value(p0c_start$) = ele%value(p0c$)
    endif
  endif
  return
endif

if (associated(a_ptr, ele%value(e_tot_start$)) .and. associated(branch)) then
  select case (ele%key)
  case (lcavity$, rfcavity$, e_gun$, em_field$)
    call set_ele_status_stale (ele, ref_energy_group$, .true.)
  case default
    ! Lord energy is set from slave. Not other way around.
    call set_ele_status_stale (ele, ref_energy_group$, .false.)
  end select
  if (dep_set) then
    call convert_total_energy_to (ele%value(e_tot_start$), branch%param%particle, pc = ele%value(p0c_start$))
  endif
  return
endif

if (associated(a_ptr, ele%value(p0c_start$)) .and. associated(branch)) then
  select case (ele%key)
  case (lcavity$, rfcavity$, e_gun$, em_field$)
    call set_ele_status_stale (ele, ref_energy_group$, .true.)
  case default
    ! Lord energy is set from slave. Not other way around.
    call set_ele_status_stale (ele, ref_energy_group$, .false.)
  end select
  if (dep_set) then
    call convert_pc_to (ele%value(p0c_start$), branch%param%particle, e_tot = ele%value(e_tot_start$))
  endif
  return
endif

!

if (associated(a_ptr, ele%value(num_steps$))) then
  if (dep_set .and. ele%value(num_steps$) /= 0) ele%value(ds_step$) = abs(ele%value(l$)) / ele%value(num_steps$)
  return
endif

!

select case (ele%key)
case (beginning_ele$) 
  coupling_change = .false.

  if (associated(a_ptr, ele%a%beta) .or. associated(a_ptr, ele%a%alpha)) then
    if (dep_set) then
      if (ele%a%beta /= 0) ele%a%gamma = (1 + ele%a%alpha**2) / ele%a%beta
    endif
    return
  endif

  if (dep_set) then
    if (associated(a_ptr, ele%b%beta) .or. associated(a_ptr, ele%b%alpha)) then
      if (ele%b%beta /= 0) ele%b%gamma = (1 + ele%b%alpha**2) / ele%b%beta
    endif
    return
  endif

  if (dep_set) then
    if (associated(a_ptr, ele%c_mat(1,1)) .or. associated(a_ptr, ele%c_mat(1,2)) .or. & 
            associated(a_ptr, ele%c_mat(2,1)) .or. associated(a_ptr, ele%c_mat(2,2))) then
      ele%gamma_c = sqrt(1 - ele%c_mat(1,1)*ele%c_mat(2,2) + ele%c_mat(1,2)*ele%c_mat(2,1))
      coupling_change = .true.
    endif
  endif

  if (dep_set) then
    if (associated(a_ptr, ele%x%eta) .or. associated(a_ptr, ele%x%etap) .or. &
        associated(a_ptr, ele%y%eta) .or. associated(a_ptr, ele%y%etap) .or. &
        coupling_change) then 
      call make_v_mats (ele, v_mat, v_inv_mat)
      eta_xy_vec = [ele%x%eta, ele%x%etap, ele%y%eta, ele%y%etap]
      eta_vec = matmul (v_inv_mat, eta_xy_vec)
      ele%a%eta  = eta_vec(1)
      ele%a%etap = eta_vec(2)
      ele%b%eta  = eta_vec(3)
      ele%b%etap = eta_vec(4)
      return
    endif
  endif

  if (dep_set) then
    if (associated(a_ptr, ele%a%eta) .or. associated(a_ptr, ele%a%etap) .or. &
        associated(a_ptr, ele%b%eta) .or. associated(a_ptr, ele%b%etap)) then 
      call make_v_mats (ele, v_mat, v_inv_mat)
      eta_vec = [ele%a%eta, ele%a%etap, ele%b%eta, ele%b%etap]
      eta_xy_vec = matmul (v_mat, eta_vec)
      ele%x%eta  = eta_xy_vec(1)
      ele%x%etap = eta_xy_vec(2)
      ele%y%eta  = eta_xy_vec(3)
      ele%y%etap = eta_xy_vec(4)
      return
    endif
  endif

  if (associated(a_ptr, ele%floor%r(1)) .or. associated(a_ptr, ele%floor%r(2)) .or. &
      associated(a_ptr, ele%floor%r(3)) .or. associated(a_ptr, ele%floor%theta) .or. &
      associated(a_ptr, ele%floor%phi) .or. associated(a_ptr, ele%floor%psi)) then
    call set_ele_status_stale (ele, floor_position_group$)
    return
  endif

case (crystal$)
  if (associated(a_ptr, ele%value(graze_angle_in$)) .or. associated(a_ptr, ele%value(graze_angle_out$))) then
    call set_ele_status_stale (ele, floor_position_group$)
    return
  endif

case (mirror$, multilayer_mirror$)
  if (associated(a_ptr, ele%value(graze_angle$))) then
    call set_ele_status_stale (ele, floor_position_group$)
    return
  endif

case (fork$, photon_fork$)

case (rfcavity$)
  if (dep_set) then
    if (associated(a_ptr, ele%value(voltage$)) .and. ele%value(l$) /= 0) ele%value(gradient$) = ele%value(voltage$) / ele%value(l$)
  endif

case (lcavity$, e_gun$)

  if (associated(a_ptr, ele%value(gradient$)) .or. associated(a_ptr, ele%value(phi0$)) .or. &
      associated(a_ptr, ele%value(voltage$)) .or. associated(a_ptr, ele%value(rf_frequency$)) .or. &
      associated(a_ptr, ele%value(phi0_autoscale$))) then
    call set_ele_status_stale (ele, ref_energy_group$)
  endif

  if (dep_set) then
    if (associated(a_ptr, ele%value(voltage$)) .and. ele%value(l$) /= 0) ele%value(gradient$) = ele%value(voltage$) / ele%value(l$)
    if (associated(a_ptr, ele%value(voltage_err$)) .and. ele%value(l$) /= 0) ele%value(gradient_err$) = ele%value(voltage_err$) / ele%value(l$)
  endif

  if (ele%key == lcavity$) then 
    if (associated(a_ptr, ele%value(phi0_multipass$)) .or. associated(a_ptr, ele%value(e_loss$))) then
       call set_ele_status_stale (ele, ref_energy_group$)
    endif
  endif

  found = .false.

  if (associated(ele%cylindrical_map)) then
    do i = 1, size(ele%cylindrical_map)
      cl_map => ele%cylindrical_map(i)
      if (associated(a_ptr, cl_map%phi0_fieldmap)) found = .true.
      if (associated(a_ptr, cl_map%field_scale)) found = .true.
      if (cl_map%master_parameter > 0) found = (found .or. associated(a_ptr, ele%value(cl_map%master_parameter)))
      if (associated(a_ptr, cl_map%phi0_fieldmap)) found = .true.
    enddo
  endif

  if (associated(ele%grid_field)) then
    do i = 1, size(ele%grid_field)
      g_field => ele%grid_field(i)
      if (associated(a_ptr, g_field%phi0_fieldmap)) found = .true.
      if (associated(a_ptr, g_field%field_scale)) found = .true.
      if (g_field%master_parameter > 0) found = (found .or. associated(a_ptr, ele%value(g_field%master_parameter)))
      if (associated(a_ptr, g_field%phi0_fieldmap)) found = .true.
    enddo
  endif

  if (found) call set_ele_status_stale (ele, ref_energy_group$)

case (patch$)
  ! Any attribute change will shift the reference time.
  call set_ele_status_stale (ele, ref_energy_group$)
  call set_ele_status_stale (ele, floor_position_group$)

case (floor_shift$, fiducial$)
  call set_ele_status_stale (ele, floor_position_group$)

case (sbend$)
  if (associated(a_ptr, ele%value(angle$)) .or. associated(a_ptr, ele%value(g$)) .or. &
      associated(a_ptr, ele%value(rho$))) then
    call set_ele_status_stale (ele, floor_position_group$)
  endif

end select

end subroutine set_flags_for_changed_real_attribute

end module
