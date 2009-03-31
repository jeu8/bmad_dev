module element_modeling_mod

use bmad

type wiggler_modeling_common_struct
  real(rp) :: integral_g2_wgt    = 1e4
  real(rp) :: integral_g3_wgt    = 1e4
  real(rp) :: x_wgt     = 1e10
  real(rp) :: mat6_wgt  = 1e6
  real(rp) :: g_step   = 1e-8  ! Step size for calculating derivatives
  real(rp) :: k_step   = 1e-7  ! Step size for calculating derivatives
  real(rp) :: len_step = 1e-6  ! Step size for calculating derivatives
  real(rp) :: integration_ds = 0.001 ! meters
  logical :: print_results = .false.
end type

type (wiggler_modeling_common_struct), save, target :: wig_model_com
type (ele_struct), private, save, pointer :: wig_com
type (lat_struct), private, save, pointer :: lat_com

private wig_func, yfit_calc, mat_flatten

real(rp), private, save :: a_step(5) 
integer, private, save :: n_ele, first_peak_polarity
logical, private, save :: even_pole_num

contains

!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!+
! Subroutine create_sol_quad_model (sol_quad, lat)
!
! Not yet implemented!
!-

subroutine create_sol_quad_model (sol_quad, lat)

implicit none

type (ele_struct) sol_quad
type (lat_struct) lat

character(40) :: r_name = 'create_sol_quad_model'

!

call out_io (s_fatal$, r_name, 'THIS ROUTINE NOT YET IMPLEMENTED!')
call err_exit

end subroutine

!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!+
! Subroutine create_wiggler_model (wiggler, lat)
!
! Routine to create series of bend and drift elements to serve as a model for a wiggler.
! This routine uses the mrqmin nonlinear optimizer to vary the parameters in the wiggler 
! model to match:
!   Integral g^2
!   Integral g^3
!   Transfer matrix.
! Also the endding horizontal transverse offset of the reference orbit (floor%x) is
! matched to zero.
!
! Note: The resulting model does not have the vertical cubic nonlinearity that
! the actual wiggler has.
!
! Modules needed:
!   use element_modeling_mod
!
! Input:
!   wiggler       -- Ele_struct: Map_type wiggler to match to.
!   wig_model_com -- Wiggler_modeling_common_struct: Global variable that can be used
!                      to set weights and step sizes for the optimization.
!
! Output:
!   lat -- Lat_struct: Lattice containing the wiggler model
!     %ele(:)      -- Array of bends and drifts.
!     %n_ele_track -- Number of elements in the model.
!-

subroutine create_wiggler_model (wiggler, lat)

use super_recipes_mod

implicit none

type (lat_struct), target :: lat
type (ele_struct), target :: wiggler
type (ele_struct), pointer :: ele 
type (lat_param_struct) param
type (coord_struct) here
type (em_field_struct) field
type (wiggler_modeling_common_struct), pointer :: c

real(rp) s, B_y, b2_int, b3_int, B_max, r, len_bend, sum_angle
real(rp) g_max, g2_int, g3_int, g_factor, a_lambda, chisq_old, chisq
real(rp) mat6(6,6), vec0(6)
real(rp), allocatable :: y(:), yfit(:), weight(:), a(:), covar(:,:), alpha(:,:)

integer i, k, n_pole, last_peak_polarity
integer i_max, n_var, n_data, status

character(40) :: r_name = 'create_wiggler_model'

! Check

wig_com => wiggler  ! For yfit_calc
lat_com => lat      ! For yfit_calc

if (wiggler%key /= wiggler$) then
  call out_io (s_fatal$, r_name, 'Element is not a wiggler!: ' // wiggler%name)
  call err_exit
endif

! Calculate integrals and maximum field

c => wig_model_com
g_factor = c_light / wiggler%value(p0c$)

if (wiggler%sub_key == map_type$) then

  here%vec = 0
  i_max = nint(wiggler%value(l$) / c%integration_ds)
  b_max = 0
  b2_int = 0
  b3_int = 0

  do i = 0, i_max

    s = i * wiggler%value(l$) / i_max
    call em_field_calc (wiggler, param, s, here, .true., field)
    B_y = field%b(2)

    b2_int = b2_int + B_y**2
    b3_int = b3_int + abs(B_y)**3
    B_max = max(B_max, abs(B_y))
    
  enddo

  b2_int = b2_int * wiggler%value(l$) / i_max
  b3_int = b3_int * wiggler%value(l$) / i_max

  g_max = g_factor * b_max
  g2_int = b2_int * g_factor**2
  g3_int = b3_int * g_factor**3

  ! Find the number of poles

  n_pole = 0
  last_peak_polarity = 0   ! Can be -1, 0, or 1

  ! count the number of poles

  do i = 0, i_max

    s = i * wiggler%value(l$) / i_max
    call em_field_calc (wiggler, param, s, here, .true., field)
    r = field%b(2) / B_max

    if (r > 0.1) then
      if (last_peak_polarity == -1) then
        n_pole = n_pole + 1
      endif
      if (n_pole == 0) first_peak_polarity = 1
      last_peak_polarity = 1
    elseif (r < -0.1) then
      if (last_peak_polarity == 1) then
        n_pole = n_pole + 1
      endif
      if (n_pole == 0) first_peak_polarity = -1
      last_peak_polarity = -1
    elseif (abs(r) < 0.01) then
      if (last_peak_polarity /= 0) then
        n_pole = n_pole + 1
      endif
      last_peak_polarity = 0
    endif  

  enddo

! Else it is a periodic type wiggler

else

  first_peak_polarity = 1 ! Arbitrary
  g_max  = wiggler%value(b_max$) * g_factor
  g2_int = g_max**2 / 2
  g3_int = 4 * g_max**3 / (3 * pi)  
  n_pole = wiggler%value(n_pole$)

endif

! Construct the initial wiggler model.
!
! If n_pole is even:
!   D_end, B_25+, D_end2, B_75-, n_main*(D, B+, D, B-), D, B_75+, D_end2, B_25- D_end 
! Where
!   n_main = (n_pole - 4) / 2
!
! If n_pole is odd:
!   D_end, B_50+, n_main*(D, B-, D, B+), D, B-, D, B_50+, D_end
! Where
!   n_main = (n_pole - 3) / 2
! Note: Odd number of poles ensures reference orbit at end aligns with orbit at the beginning.
!
! Also:
!   n_bends  = n_pole
!   n_drifts = n_pole + 1
!   B_nn -> Bend has length nn% of main dipoles.
!   +/-  -> Sign of bend.

! Take for an initial guess that len_main_bends = 4 * len_main_drifts
! And take all drift lengths equal.

n_ele = 2 * n_pole + 1
call init_lat (lat, n_ele)

lat%n_ele_track = n_ele
lat%n_ele_max   = n_ele
lat%ele(0)%value(p0c$) = wiggler%value(p0c$)
lat%ele(0)%value(e_tot$) = wiggler%value(e_tot$)
lat%param%particle = positron$

! Simple model if there is no field

if (g_max == 0) then
  lat%n_ele_track = 1
  lat%n_ele_max = 1
  lat%ele(1)%key = drift$
  lat%ele(1)%value(l$) = wiggler%value(l$)
  lat%ele(1)%name = wiggler%name
  call lattice_bookkeeper (lat_com)
  call lat_make_mat6 (lat_com)
  return
endif

!

even_pole_num = (mod(n_pole, 2) == 0)

if (even_pole_num) then
  len_bend = 4 * wiggler%value(l$) / (5 * n_pole - 7)
else
  len_bend = 4 * wiggler%value(l$) / (5 * n_pole - 3)
endif

sum_angle = 0

do i = 1, n_pole

  ele => lat%ele(2*i)

  if (even_pole_num) then
    if (i == 1 .or. i == n_pole) then
      ele%value(l$) = len_bend / 4
      ele%name = trim(wiggler%name) // '_B25'
    elseif (i == 2 .or. i == n_pole-1) then
      ele%value(l$) = 3 * len_bend / 4
      ele%name = trim(wiggler%name) // '_B75'
    else
      ele%value(l$) = len_bend 
      ele%name = trim(wiggler%name) // '_B'
    endif
  else
    if (i == 1 .or. i == n_pole) then
      ele%value(l$) = len_bend / 2
      ele%name = trim(wiggler%name) // '_B50'
    else
      ele%value(l$) = len_bend 
      ele%name = trim(wiggler%name) // '_B'
    endif
  endif

  ! Mark bend polarity
  if (mod(i, 2) == 0) then
    ele%name = trim(ele%name) // 'P'  
  else
    ele%name = trim(ele%name) // 'N'
  endif

  ele%key = sbend$
  ele%sub_key = sbend$
  ele%value(e1$) = -sum_angle
  ele%value(g$) = first_peak_polarity * (-1)**(i-1) * g_max
  sum_angle = sum_angle + ele%value(g$) * ele%value(l$)
  ele%value(e2$) = sum_angle

enddo

lat%ele(1:n_ele:2)%key       = drift$
lat%ele(1:n_ele:2)%name      = trim(wiggler%name) // '_D'
lat%ele(1:n_ele:2)%value(l$) = len_bend / 4
  lat%ele(1)%name        = trim(wiggler%name) // '_D1'
  lat%ele(n_ele)%name    = trim(wiggler%name) // '_D1'
if (even_pole_num) then
  lat%ele(3)%name        = trim(wiggler%name) // '_D2'
  lat%ele(n_ele-2)%name  = trim(wiggler%name) // '_D2'
endif

call lattice_bookkeeper (lat)

! Optimize the wiggler parameters:
! Variables:
!   g, len_b, len_d_end, k1, len_d_end2 (Even only)
!
! Possible:
!   fint, hgap
!
! Data to fit:
!   Difference: mat6(1:2,1:2), mat6(3:4,3:4), mat6(1,6), g2_int, g3_int
!   ele%floor%x = 0

if (even_pole_num) then
  n_var = 5
else
  n_var = 4
endif
n_data = 12

allocate (y(n_data), yfit(n_data), weight(n_data))
allocate (a(n_var), covar(n_var, n_var), alpha(n_var,n_var))

a(1:4) = (/ g_max, 0.0_rp, len_bend, len_bend/4 /)
if (even_pole_num) a(5) = len_bend/4

a_step = (/ c%g_step, c%k_step, c%len_step, c%len_step, c%len_step /)

call make_mat6 (wiggler, lat%param)

weight(1:3) = (/ c%integral_g2_wgt, c%integral_g3_wgt, c%x_wgt /)
weight(4:)  = c%mat6_wgt
y = (/ g2_int, g3_int, 0.0_rp, mat_flatten(wiggler%mat6) /)

a_lambda = -1
chisq_old = 1e10

do i = 1, 10000
  call super_mrqmin (y, weight, a, covar, alpha, chisq, wig_func, a_lambda, status)
  if (c%print_results) then
    if (chisq/chisq_old < 0.90 .or. i == 10000 .or. a_lambda > 1e10) then
      print *, '---------------------------'
      print '(i6, es12.3, es10.1)', i, chisq, a_lambda
      call yfit_calc (a, yfit, status)
      print *, 'Wiggler:'
      call mat_type (wiggler%mat6)
      print *
      print *, 'Model:'
      call lat_make_mat6 (lat)
      call transfer_matrix_calc (lat, .true., mat6, vec0)
      call mat_type (mat6)
      print *
      print *, 'Wiggler g2_int, g3_int:', g2_int, g3_int
      print *, 'Model   g2_int, g3_int:', yfit(1), yfit(2)
      print *, 'Floor: ', lat%ele(n_ele)%floor%theta, lat%ele(n_ele)%floor%x, lat%ele(n_ele)%floor%z
      print *, 'L:', wiggler%value(l$), lat%ele(n_ele)%s
      print *, 'chi2_g2:   ', weight(1) * (yfit(1) - y(1))**2
      print *, 'chi2_g3:   ', weight(2) * (yfit(2) - y(2))**2
      print *, 'chi2_x:    ', weight(3) * (yfit(3) - y(3))**2
      print *, 'chi2_m12:  ', weight(4) * sum((yfit(4: 7) - y(4: 7))**2)
      print *, 'chi2_m34:  ', weight(8) * sum((yfit(8:11) - y(8:11))**2)
      print *, 'chi2_m16:  ', weight(12)* (yfit(12) - y(12))**2
      chisq_old = chisq
    endif
  endif
  if (a_lambda > 1e10) exit
enddo

deallocate (y, yfit, weight, a, covar, alpha)

end subroutine

!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!+
! This routine is not for general use.
!-

subroutine wig_func (a, yfit, dyda, status)

implicit none

real(rp), intent(in) :: a(:)
real(rp), intent(out) :: yfit(:)
real(rp), intent(out) :: dyda(:,:)
real(rp) :: a_try(size(a)), y_try(size(yfit))

integer i
integer status

!

call yfit_calc (a, yfit, status)
do i = 1, size(a)
  a_try = a
  a_try(i) = a_try(i) + a_step(i)
  call yfit_calc (a_try, y_try, status)
  dyda(:,i) = (y_try - yfit) / a_step(i)
enddo

end subroutine

!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!+
! This routine is not for general use.
!-

subroutine yfit_calc (a, yfit, status)

implicit none

type (ele_struct), pointer :: ele

real(rp), intent(in) :: a(:)
real(rp), intent(out) :: yfit(:)
real(rp) g, g2_int, g3_int, len_bend, len_drift, k1, sum_angle, len_d_end2, len_d_end
real(rp) mat6(6,6), vec0(6)

integer status
integer i, n_pole

!

g = a(1)
k1 = a(2)
len_bend = a(3)
len_drift = a(4)
n_pole = (n_ele - 1) / 2
sum_angle = 0

do i = 1, n_pole

  ele => lat_com%ele(2*i)

  if (even_pole_num) then
    if (i == 1 .or. i == n_pole) then
      ele%value(l$) = len_bend / 4
    elseif (i == 2 .or. i == n_pole-1) then
      ele%value(l$) = 3 * len_bend / 4
    else
      ele%value(l$) = len_bend 
    endif
  else
    if (i == 1 .or. i == n_pole) then
      ele%value(l$) = len_bend / 2
    else
      ele%value(l$) = len_bend 
    endif
  endif

  ele%value(e1$) = -sum_angle
  ele%value(g$) = first_peak_polarity * (-1)**(i-1) * g
  sum_angle = sum_angle + ele%value(g$) * ele%value(l$)
  ele%value(e2$) = sum_angle
  ele%value(k1$) = k1

enddo

lat_com%ele(1:n_ele:2)%value(l$) = len_drift
if (even_pole_num) then
  len_d_end2 = a(5)
  lat_com%ele(3)%value(l$) = len_d_end2
  lat_com%ele(n_ele-2)%value(l$) = len_d_end2
endif

len_d_end = (wig_com%value(l$) - sum(lat_com%ele(2:n_ele-1)%value(l$))) / 2
lat_com%ele(1)%value(l$) = len_d_end
lat_com%ele(n_ele)%value(l$) = len_d_end

call lattice_bookkeeper (lat_com)

call lat_make_mat6 (lat_com)
call transfer_matrix_calc (lat_com, .true., mat6, vec0)

if (even_pole_num) then
  g2_int = g**2 * (n_pole - 2) * len_bend
  g3_int = g**3 * (n_pole - 2) * len_bend
else
  g2_int = g**2 * (n_pole - 1) * len_bend
  g3_int = g**3 * (n_pole - 1) * len_bend
endif

yfit = (/ g2_int, g3_int, lat_com%ele(n_ele)%floor%x, mat_flatten(mat6) /)

end subroutine

!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!+
! This routine is not for general use.
!-

function mat_flatten (mat6) result (vec9)

implicit none

real(rp) mat6(:,:)
real(rp) vec9(9)

!

vec9 = (/ mat6(1,1:2), mat6(2,1:2), mat6(3,3:4), mat6(4,3:4), mat6(1,6) /)

end function

end module
