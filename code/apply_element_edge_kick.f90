!+
! Subroutine apply_element_edge_kick (orb, s_edge, t_rel, hard_ele, track_ele, param, particle_at, track_spin)
!
! Subroutine, used with runge_kutta and boris tracking, to track through the edge fringe field of an element.
! This routine is used and with the bmad_standard field_calc where the field can have an abrubt, 
! unphysical termination of the field at the edges of the element. 
!
! Elements that have kicks due to unphysical edge field termination include:
!   sbend
!   solenoid
!   sol_quad
!   lcavity
!   rfcavity 
!   e_gun
! Additionally, Any element that has an electric multipole has an edge kick.
!
! Input:
!   orb         -- Coord_struct: Starting coords in element reference frame.
!   s_edge      -- real(rp): Hard edge relative to start of hard_ele.
!   t_rel       -- real(rp): Time relative to track_ele entrance edge
!   hard_ele    -- ele_struct: Element with hard edges.
!   track_ele   -- ele_struct: Element being tracked through. Is different from hard_ele
!                    when there are superpositions and track_ele can be a super_slave of hard_ele.
!   param       -- lat_param_struct: lattice parameters.
!   particle_at -- integer: first_track_edge$ or second_track_edge$
!   track_spin  -- logical: Track the spin?
!
! Output:
!   orb        -- Coord_struct: Coords after application of the edge fringe field.
!-

subroutine apply_element_edge_kick (orb, s_edge, t_rel, hard_ele, track_ele, param, particle_at, track_spin)

use track1_mod, except_dummy => apply_element_edge_kick

implicit none

type (ele_struct) hard_ele, track_ele
type (coord_struct) orb
type (lat_param_struct) param
type (em_field_struct) field

real(rp) t, f, l_drift, ks, t_rel, s_edge, s, phi, omega(3), pc
complex(rp) xiy, c_vec

integer particle_at, physical_end, dir, i, fringe_at, at_sign
logical finished, track_spin, track_spn

! The setting of hard_ele%ixx is used by calc_next_fringe_edge to calculate the next fringe location.

if (particle_at == first_track_edge$) then
  hard_ele%ixx = inside$
else
  dir = orb%direction
  if (hard_ele%value(l$) < 0) dir = -dir
  if (dir == 1) then
    hard_ele%ixx = downstream_end$
  else
    hard_ele%ixx = upstream_end$
  endif
endif

! Custom edge kick?

call apply_element_edge_kick_hook (orb, s_edge, t_rel, hard_ele, track_ele, param, particle_at, finished)
if (finished) return

! Only need this routine when the field is calculated using bmad_standard

if (track_ele%field_calc /= bmad_standard$) return

physical_end = physical_ele_end (particle_at, orb%direction, track_ele%orientation)
fringe_at = nint(track_ele%value(fringe_at$))
if (.not. at_this_ele_end(physical_end, fringe_at)) return
track_spn = (track_spin .and. bmad_com%spin_tracking_on .and. is_true(track_ele%value(spin_fringe_on$)))

if (particle_at == first_track_edge$) then
  at_sign = 1
else
  at_sign = -1
endif

! Static electric longitudinal field

if (associated(hard_ele%a_pole_elec)) then
  xiy = 1
  c_vec = cmplx(orb%vec(1), orb%vec(3), rp)
  do i = 0, max_nonzero(0, hard_ele%a_pole_elec, hard_ele%b_pole_elec)
    xiy = xiy * c_vec
    if (hard_ele%a_pole_elec(i) == 0 .and. hard_ele%b_pole_elec(i) == 0) cycle
    phi = at_sign * charge_of(orb%species) * real(cmplx(hard_ele%b_pole_elec(i), -hard_ele%a_pole_elec(i), rp) * xiy) / (i + 1)
    call convert_total_energy_to (orb%p0c * (1 + orb%vec(6)) / orb%beta + phi, orb%species, beta = orb%beta, pc = pc)
    orb%vec(6) = (pc - orb%p0c) / orb%p0c

    if (track_spn) then
      call rotate_spinor_given_field (orb, track_ele, EL = [0.0_rp, 0.0_rp, phi])
    endif
  enddo
endif

! Static magnetic and electromagnetic fringes

select case (track_ele%key)
case (quadrupole$)
  if (particle_at == first_track_edge$) then
    call hard_multipole_edge_kick (track_ele, param, particle_at, orb)
    call soft_quadrupole_edge_kick (track_ele, param, particle_at, orb)
  else
    call soft_quadrupole_edge_kick (track_ele, param, particle_at, orb)
    call hard_multipole_edge_kick (track_ele, param, particle_at, orb)
  endif

case (sbend$)
  call bend_edge_kick (track_ele, param, particle_at, orb, track_spin = track_spn)

! Note: Cannot trust track_ele%value(ks$) here since element may be superimposed with an lcavity.
! So use track_ele%value(bs_field$).

case (solenoid$, sol_quad$, bend_sol_quad$)
  ks = at_sign * relative_tracking_charge(orb, param) * track_ele%value(bs_field$) * c_light / orb%p0c
  orb%vec(2) = orb%vec(2) + ks * orb%vec(3) / 2
  orb%vec(4) = orb%vec(4) - ks * orb%vec(1) / 2
  if (track_spn) then
    f = at_sign * relative_tracking_charge(orb, param) * track_ele%value(bs_field$) / 2
    call rotate_spinor_given_field (orb, track_ele, -[orb%vec(1), orb%vec(3), 0.0_rp] * f)
  endif

case (lcavity$, rfcavity$, e_gun$)

  ! Add on bmad_com%significant_length to make sure we are just inside the cavity.
  f = at_sign * charge_of(orb%species) / (2 * orb%p0c)
  t = t_rel + track_ele%value(ref_time_start$) - hard_ele%value(ref_time_start$) 
  s = s_edge

  if (at_this_ele_end(physical_end, nint(track_ele%value(fringe_at$)))) then
    if (particle_at == first_track_edge$) then
      ! Note: E_gun does not have an entrance kick
      s = s + bmad_com%significant_length / 10 ! Make sure inside field region
      call em_field_calc (hard_ele, param, s, t, orb, .true., field)
    else
      s = s - bmad_com%significant_length / 10 ! Make sure inside field region
      call em_field_calc (hard_ele, param, s, t, orb, .true., field)
    endif

    orb%vec(2) = orb%vec(2) - field%e(3) * orb%vec(1) * f + c_light * field%b(3) * orb%vec(3) * f
    orb%vec(4) = orb%vec(4) - field%e(3) * orb%vec(3) * f - c_light * field%b(3) * orb%vec(1) * f

    if (track_spn) then
      f = at_sign * charge_of(orb%species) / 2
      call rotate_spinor_given_field (orb, track_ele, -[orb%vec(1), orb%vec(3), 0.0_rp] * f * field%b(3), &
                                                      -[orb%vec(1), orb%vec(3), 0.0_rp] * f * field%e(3))
    endif

    ! orb%phase(1) is set by em_field_calc.

    call rf_coupler_kick (hard_ele, param, particle_at, orb%phase(1), orb)
  endif

case (elseparator$)
  ! Longitudinal fringe field
  f = at_sign * charge_of(orb%species) * (hard_ele%value(p0c$) / hard_ele%value(l$))
  phi = f * (hard_ele%value(hkick$) * orb%vec(1) + hard_ele%value(vkick$) * orb%vec(3))
  call convert_total_energy_to (orb%p0c * (1 + orb%vec(6)) / orb%beta + phi, orb%species, beta = orb%beta, pc = pc)
  orb%vec(6) = (pc - orb%p0c) / orb%p0c
  if (track_spn) then
    call rotate_spinor_given_field (orb, track_ele, EL = [0.0_rp, 0.0_rp, phi])
  endif

end select

end subroutine apply_element_edge_kick
