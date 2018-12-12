!+
! Subroutine create_wiggler_cartesian_map (ele, cart_map)
!
! Routine to create an "equivalent" cartesian map for helical and planar wigglers and undulators.
!
! Note: The calling routine must deallocate cart_map%ptr before cart_map goes out of scope.
!
! Input:
!   ele         -- ele_struct: Wiggler or undulator element.
!
! Output:
!   cart_map    -- cartesian_map_struct: Cartesian map.
!-

subroutine create_wiggler_cartesian_map (ele, cart_map)

use bmad_interface

implicit none

type (ele_struct) ele
type (cartesian_map_struct), target :: cart_map
type (cartesian_map_term1_struct), pointer :: term

real(rp) kk

character(*), parameter :: r_name = 'create_wiggler_cartesian_map'

! planar_model wigglers have a single Cartesian map term for use with PTC, Runge-Kutta tracking, etc.
! The phase of this term is set so that tracking with a particle starting on-axis ends on-axis.
! For this to be true, there must be an integer number of poles.
! For helical model wigglers, there are two Cartesian map terms In this case the particle 

! For super_slave and sliced elements, the phi_z is set by the position with respect to the lord in
! the routine makeup_super_slave1 and so should not be touched here.

if (.not. associated(cart_map%ptr)) allocate (cart_map%ptr)

cart_map%master_parameter = polarity$
cart_map%field_type = magnetic$


if (ele%value(l$) == 0) then
  kk = 0
else
  if (ele%value(n_pole$) == 0) then
    call out_io (s_error$, r_name, 'NUMBER OF POLES NOT SET FOR WIGGLER/UNDULATOR: ' // trim(ele%name))
    kk = pi * 2 / ele%value(l$)  ! Assume two poles
  else
    kk = pi * ele%value(n_pole$) / ele%value(l$)
  endif
endif

!

if (ele%field_calc == planar_model$) then
  if (.not. allocated(cart_map%ptr%term)) allocate (cart_map%ptr%term(1))
  if (size(cart_map%ptr%term) /= 1) then
    deallocate (cart_map%ptr%term)
    allocate (cart_map%ptr%term(1))
  endif

  term => cart_map%ptr%term(1)
  term%coef   = ele%value(b_max$)
  term%kx     = 0
  term%ky     = kk
  term%kz     = kk
  term%x0     = 0
  term%y0     = 0
  term%phi_z  = -kk * ele%value(l$) / 2 
  term%family = family_y$
  term%form   = hyper_y$

elseif (ele%field_calc == planar_model$) then
  if (.not. allocated(cart_map%ptr%term)) allocate (cart_map%ptr%term(1))
  if (size(cart_map%ptr%term) /= 2) then
    deallocate (cart_map%ptr%term)
    allocate (cart_map%ptr%term(2))
  endif

  term => cart_map%ptr%term(1)
  term%coef   = ele%value(b_max$)
  term%kx     = 0
  term%ky     = kk
  term%kz     = kk
  term%x0     = 0
  term%y0     = 0
  term%phi_z  = -kk * ele%value(l$) / 2 
  term%family = family_y$
  term%form   = hyper_y$

  term => cart_map%ptr%term(2)
  term%coef   = ele%value(b_max$)
  term%kx     = kk
  term%ky     = 0
  term%kz     = kk
  term%x0     = 0
  term%y0     = 0
  term%phi_z  = cart_map%ptr%term(1)%phi_z + pi / 2
  term%family = family_x$
  term%form   = hyper_x$

else
  call out_io (s_error$, r_name, 'BOOKKEEPING PROBLEM. PLASE GET HELP!')
  if (global_com%exit_on_error) call err_exit
  return
endif


end subroutine create_wiggler_cartesian_map
