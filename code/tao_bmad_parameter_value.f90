!+
! Function tao_bmad_parameter_value (data_type, ele, orbit, err_flag) result (value)
!
! Routine to take a Tao datam name ("beta.a", "orbit.x", etc.), translate to the corresponding Bmad parameter
! and then evaluate it at the given element or orbit position.
!
! Input:
!   data_type     -- character(*): Data name.
!   ele           -- ele_struct: Lattice element to evaluate the parameter at.
!   orbit         -- coord_struct: Orbit to evaluate the parameter at.
!
! Output:
!   err_flag      -- logical: Set true if data_type does not have a corresponding Bmad parameter.
!   value         -- real(rp): Parameter value.
!-

function tao_bmad_parameter_value (data_type, ele, orbit, err_flag) result (value)

use tao_interface, except_dummy => tao_bmad_parameter_value
use measurement_mod
use em_field_mod

implicit none

type (ele_struct) ele
type (coord_struct) orbit
type (bpm_phase_coupling_struct) bpm_data
type (floor_position_struct) floor
type (branch_struct), pointer :: branch
type (em_field_struct) field, field0, field1

real(rp) value, cbar(2,2), f, amp_a, amp_b, amp_na, amp_nb, time, dt, amp, phase

character(*) data_type
character(40) name, prefix

integer ix

logical err_flag

!

err_flag = .false.
branch => pointer_to_branch(ele)

ix = index(data_type, '.')
if (ix == 0) then
  prefix = data_type
else
  prefix = data_type(1:ix)
endif

!

select case (prefix)

case ('alpha.')
  select case (data_type)
  case ('alpha.a');          value = ele%a%alpha
  case ('alpha.b');          value = ele%b%alpha
  case ('alpha.z');          value = ele%z%alpha
  case default;              err_flag = .true.
  end select

case ('b_curl.')
  call em_field_derivatives (ele, branch%param, orbit%s-ele%s_start, orbit, .false., field)
  time = particle_rf_time(orbit, ele, (ele%field_calc /= fieldmap$), orbit%s-ele%s_start)
  dt = bmad_com%d_orb(5) / c_light
  call em_field_calc (ele, branch%param, orbit%s-ele%s_start, orbit, .false., field0, rf_time = time-dt)
  call em_field_calc (ele, branch%param, orbit%s-ele%s_start, orbit, .false., field1, rf_time = time+dt)

  select case (data_type)
  case ('b_curl.x');  value = field%dB(2,3) - field%dB(3,2) - (field1%E(1) - field0%E(1)) / (2 * dt * c_light**2)
  case ('b_curl.y');  value = field%dB(3,1) - field%dB(1,3) - (field1%E(2) - field0%E(2)) / (2 * dt * c_light**2)
  case ('b_curl.z');  value = field%dB(1,2) - field%dB(2,1) - (field1%E(3) - field0%E(3)) / (2 * dt * c_light**2)
  case default;       err_flag = .true.
  end select

case ('b_div')
  call em_field_derivatives (ele, branch%param, orbit%s-ele%s_start, orbit, .false., field)
  value = field%dB(1,1) + field%dB(2,2) + field%dB(3,3)

case ('b_field.')
  call em_field_calc (ele, branch%param, orbit%s-ele%s_start, orbit, .false., field)
  select case (data_type)
  case ('b_field.x');  value = field%b(1)
  case ('b_field.y');  value = field%b(2)
  case ('b_field.z');  value = field%b(3)
  case default;       err_flag = .true.
  end select

case ('beta.')
  select case (data_type)
  case ('beta.a');           value = ele%a%beta
  case ('beta.b');           value = ele%b%beta
  case ('beta.z');           value = ele%z%beta
  case default;              err_flag = .true.
  end select

case ('bpm_cbar.')
  call to_phase_and_coupling_reading (ele, bpm_data, err_flag)
  select case (data_type)
  case ('bpm_cbar.22a');     value = bpm_data%cbar22_a
  case ('bpm_cbar.12a');     value = bpm_data%cbar12_a
  case ('bpm_cbar.11b');     value = bpm_data%cbar11_b
  case ('bpm_cbar.12b');     value = bpm_data%cbar12_b
  case default
  end select

case ('bpm_eta.')
  select case (data_type)
  case ('bpm_eta.x');        call to_eta_reading ([ele%x%eta, ele%y%eta], ele, x_plane$, value, err_flag)
  case ('bpm_eta.y');        call to_eta_reading ([ele%x%eta, ele%y%eta], ele, y_plane$, value, err_flag)
  case default;              err_flag = .true.
  end select

case ('bpm_orbit.')
  select case (data_type)
  case ('bpm_orbit.x');      call to_orbit_reading (orbit, ele, x_plane$, value, err_flag)
  case ('bpm_orbit.y');      call to_orbit_reading (orbit, ele, y_plane$, value, err_flag)
  case default;              err_flag = .true.
  end select

case ('bpm_phase.')
  call to_phase_and_coupling_reading (ele, bpm_data, err_flag)
  if (err_flag) return
  select case (data_type)
  case ('bpm_phase.a');      value = bpm_data%phi_a
  case ('bpm_phase.b');      value = bpm_data%phi_b
  case default;              err_flag = .true.
  end select

case ('bpm_k.')
  call to_phase_and_coupling_reading (ele, bpm_data, err_flag)
  select case (data_type)
  case ('bpm_k.22a');        value = bpm_data%k_22a
  case ('bpm_k.12a');        value = bpm_data%k_12a
  case ('bpm_k.11b');        value = bpm_data%k_11b
  case ('bpm_k.12b');        value = bpm_data%k_12b
  case default;              err_flag = .true.
  end select

case ('c_mat.')
  select case (data_type)
  case ('c_mat.11');         value = ele%c_mat(1,1)
  case ('c_mat.12');         value = ele%c_mat(1,2)
  case ('c_mat.21');         value = ele%c_mat(2,1)
  case ('c_mat.22');         value = ele%c_mat(2,2)
  case default;              err_flag = .true.
  end select

case ('cbar.')
  call c_to_cbar (ele, cbar)
  select case (data_type)
  case ('cbar.11');          value = cbar(1,1)
  case ('cbar.12');          value = cbar(1,2)
  case ('cbar.21');          value = cbar(2,1)
  case ('cbar.22');          value = cbar(2,2)
  case default;              err_flag = .true.
  end select

case ('coupling.')
  call c_to_cbar (ele, cbar)  
  select case (data_type)
  case ('coupling.11b');  value = cbar(1,1) * sqrt(ele%a%beta/ele%b%beta) / ele%gamma_c
  case ('coupling.12a');  value = cbar(1,2) * sqrt(ele%b%beta/ele%a%beta) / ele%gamma_c
  case ('coupling.12b');  value = cbar(1,2) * sqrt(ele%a%beta/ele%b%beta) / ele%gamma_c
  case ('coupling.22a');  value = cbar(2,2) * sqrt(ele%b%beta/ele%a%beta) / ele%gamma_c
  case default;           err_flag = .true.
  end select

case ('e_curl.')
  call em_field_derivatives (ele, branch%param, orbit%s-ele%s_start, orbit, .false., field)
  time = particle_rf_time(orbit, ele, (ele%field_calc /= fieldmap$), orbit%s-ele%s_start)
  dt = bmad_com%d_orb(5) / c_light
  call em_field_calc (ele, branch%param, orbit%s-ele%s_start, orbit, .false., field0, rf_time = time-dt)
  call em_field_calc (ele, branch%param, orbit%s-ele%s_start, orbit, .false., field1, rf_time = time+dt)

  select case (data_type)
  case ('e_curl.x');  value = field%dE(2,3) - field%dE(3,2) + (field1%B(1) - field0%B(1)) / (2 * dt)
  case ('e_curl.y');  value = field%dE(3,1) - field%dE(1,3) + (field1%B(2) - field0%B(2)) / (2 * dt)
  case ('e_curl.z');  value = field%dE(1,2) - field%dE(2,1) + (field1%B(3) - field0%B(3)) / (2 * dt)
  case default;           err_flag = .true.
  end select

case ('e_div')
  call em_field_derivatives (ele, branch%param, orbit%s-ele%s_start, orbit, .false., field)
  value = field%dE(1,1) + field%dE(2,2) + field%dE(3,3)

case ('e_field.')
  call em_field_calc (ele, branch%param, orbit%s-ele%s_start, orbit, .false., field)
  select case (data_type)
  case ('e_field.x');  value = field%e(1)
  case ('e_field.y');  value = field%e(2)
  case ('e_field.z');  value = field%e(3)
  case default;           err_flag = .true.
  end select

case ('e_tot_ref');          value = ele%value(e_tot$)

case ('eta.')
  select case (data_type)
  case ('eta.a');            value = ele%a%eta
  case ('eta.b');            value = ele%b%eta
  case ('eta.x');            value = ele%x%eta
  case ('eta.y');            value = ele%y%eta
  case ('eta.z');            value = ele%z%eta
  case default;              err_flag = .true.
  end select

case ('etap.')
  select case (data_type)
  case ('etap.a');           value = ele%a%etap
  case ('etap.b');           value = ele%b%etap
  case ('etap.x');           value = ele%x%etap
  case ('etap.y');           value = ele%y%etap
  case default;              err_flag = .true.
  end select

case ('floor.')
  select case (data_type)
  case ('floor.x');          value = ele%floor%r(1)
  case ('floor.y');          value = ele%floor%r(2)
  case ('floor.z');          value = ele%floor%r(3)
  case ('floor.theta');      value = ele%floor%theta
  case ('floor.phi');        value = ele%floor%phi
  case ('floor.psi');        value = ele%floor%psi
  case default;              err_flag = .true.
  end select

case ('floor_actual.')
  floor = ele_geometry_with_misalignments(ele)
  select case (data_type)
  case ('floor_actual.x');          value = floor%r(1)
  case ('floor_actual.y');          value = floor%r(2)
  case ('floor_actual.z');          value = floor%r(3)
  case ('floor_actual.theta');      value = floor%theta
  case ('floor_actual.phi');        value = floor%phi
  case ('floor_actual.psi');        value = floor%psi
  case default;              err_flag = .true.
  end select

case ('floor_orbit.')
  floor%r = [orbit%vec(1), orbit%vec(3), ele%value(l$)]
  floor = coords_local_curvilinear_to_floor (floor, ele, .false.)
  select case (data_type)
  case ('floor_orbit.x');          value = floor%r(1)
  case ('floor_orbit.y');          value = floor%r(2)
  case ('floor_orbit.z');          value = floor%r(3)
  case default;              err_flag = .true.
  end select

case ('gamma.')
  select case (data_type)
  case ('gamma.a');          value = ele%a%gamma
  case ('gamma.b');          value = ele%b%gamma
  case ('gamma.z');          value = ele%z%gamma
  case default;              err_flag = .true.
  end select

case ('k.')
  call c_to_cbar (ele, cbar)
  f = sqrt(ele%a%beta/ele%b%beta) 
  select case (data_type)
  case ('k.11b');            value = cbar(1,1) * f / ele%gamma_c
  case ('k.12a');            value = cbar(1,2) / (f * ele%gamma_c)
  case ('k.12b');            value = cbar(1,2) * f / ele%gamma_c
  case ('k.22a');            value = cbar(2,2) / (f * ele%gamma_c)
  case default;              err_flag = .true.
  end select

case ('momentum');            value = (1 + orbit%vec(6)) * orbit%p0c

case ('orbit.')
  if (data_type(7:9) == 'amp' .or. data_type(7:9) == 'nor') &
          call orbit_amplitude_calc (ele, orbit, amp_a, amp_b, amp_na, amp_nb)
  select case (data_type)
  case ('orbit.x');           value = orbit%vec(1)
  case ('orbit.y');           value = orbit%vec(3)
  case ('orbit.z');           value = orbit%vec(5)
  case ('orbit.px');          value = orbit%vec(2)
  case ('orbit.py');          value = orbit%vec(4)
  case ('orbit.pz');          value = orbit%vec(6)
  case ('orbit.amp_a');       value = amp_a
  case ('orbit.amp_b');       value = amp_b
  case ('orbit.norm_amp_a');  value = amp_na
  case ('orbit.norm_amp_b');  value = amp_nb
  case ('orbit.e_tot')
    if (orbit%beta == 0) then
      value = mass_of(branch%param%particle)
    else
      value = orbit%p0c * (1 + orbit%vec(6)) / orbit%beta
    endif
  case default;               err_flag = .true.
  end select

case ('pc');                  value = (1 + orbit%vec(6)) * orbit%p0c

case ('phase.', 'phase_frac.')
  select case (data_type)
  case ('phase.a');           value = ele%a%phi
  case ('phase_frac.a');      value = modulo2 (ele%a%phi, pi)
  case ('phase.b');           value = ele%b%phi
  case ('phase_frac.b');      value = modulo2 (ele%b%phi, pi)
  case default;               err_flag = .true.
  end select

case ('ping_a.')
  call c_to_cbar (ele, cbar)
  select case (data_type)
  case ('ping_a.amp_x');          value = ele%gamma_c * sqrt(ele%a%beta)
  case ('ping_a.phase_x');        value = ele%a%phi
  case ('ping_a.amp_y');          value = sqrt(ele%b%beta * (cbar(1,2)**2 + cbar(2,2)**2))
  case ('ping_a.phase_y');        value = ele%a%phi + atan2(cbar(1,2), -cbar(2,2))
  case ('ping_a.amp_sin_rel_y');  value = -sqrt(ele%b%beta) * cbar(1,2)
  case ('ping_a.amp_cos_rel_y');  value = -sqrt(ele%b%beta) * cbar(2,2)
  case ('ping_a.amp_sin_y')
    amp = sqrt(ele%b%beta * (cbar(1,2)**2 + cbar(2,2)**2))
    phase = ele%a%phi + atan2(cbar(1,2), -cbar(2,2))
    value = amp * sin(phase)
  case ('ping_a.amp_cos_y')
    amp = sqrt(ele%b%beta * (cbar(1,2)**2 + cbar(2,2)**2))
    phase = ele%a%phi + atan2(cbar(1,2), -cbar(2,2))
    value = amp * cos(phase)
  case default;               err_flag = .true.
  end select

case ('ping_b.')
  call c_to_cbar (ele, cbar)
  select case (data_type)
  case ('ping_b.amp_y');          value = ele%gamma_c * sqrt(ele%b%beta)
  case ('ping_b.phase_y');        value = ele%b%phi
  case ('ping_b.amp_x');          value = sqrt(ele%a%beta * (cbar(1,2)**2 + cbar(1,1)**2))
  case ('ping_b.phase_x');        value = ele%b%phi + atan2(cbar(1,2), cbar(1,1))
  case ('ping_b.amp_sin_rel_x');  value = -sqrt(ele%a%beta) * cbar(1,2)
  case ('ping_b.amp_cos_rel_x');  value = sqrt(ele%a%beta) * cbar(1,1)
  case ('ping_b.amp_sin_x')
    amp = sqrt(ele%a%beta * (cbar(1,2)**2 + cbar(1,1)**2))
    phase = ele%b%phi + atan2(cbar(1,2), cbar(1,1))
    value = amp * sin(phase)
  case ('ping_b.amp_cos_x')
    amp = sqrt(ele%a%beta * (cbar(1,2)**2 + cbar(1,1)**2))
    phase = ele%b%phi + atan2(cbar(1,2), cbar(1,1))
    value = amp * cos(phase)
  case default;               err_flag = .true.
  end select

case ('ref_time');            value = ele%ref_time

case ('spin.')
  select case (data_type)
  case ('spin.x');        value = orbit%spin(1)
  case ('spin.y');        value = orbit%spin(2)
  case ('spin.z');        value = orbit%spin(3)
  case ('spin.amp');      value = norm2(orbit%spin)
  case default;           err_flag = .true.
  end select

case ('s_position');         value = ele%s

case ('time');               value = orbit%t

case ('velocity', 'velocity.')
  select case (data_type)
  case ('velocity');  value = orbit%beta
  case ('velocity.x');  value = orbit%vec(2) * (1 + orbit%vec(6)) * orbit%beta
  case ('velocity.y');  value = orbit%vec(4) * (1 + orbit%vec(6)) * orbit%beta
  case ('velocity.z');  value = sqrt(1 - (orbit%vec(2) * (1 + orbit%vec(6)))**2 - (orbit%vec(4) * (1 + orbit%vec(6)))**2) * orbit%beta
  case default;           err_flag = .true.
  end select

case default;                err_flag = .true.

end select

end function
