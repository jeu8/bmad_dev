!+
! Subroutine tao_lmdif_optimizer ()
!
! Subrutine to minimize the merit function by varying variables until
! the "data" as calculated from the model matches the measured data.
! 
! This subroutine is a wrapper for the mrqmin routine of Numerical Recipes.
! See the Numerical Recipes writeup for more details.
! 'lm' stands for Levenburg - Marquardt. Otherwise known as LMDIF. 
!
! Note: LM assumes 
!
! Input:
!
! Output:
!-

subroutine tao_lmdif_optimizer ()

use tao_mod
use tao_dmerit_mod
use tao_top10_mod
use tao_var_mod
use single_char_input_mod
use lmdif_mod

implicit none

type (tao_universe_struct), pointer :: u

real(rp), allocatable, save :: merit_vec(:), weight(:)
real(rp), allocatable, save :: var_delta(:), var_value(:), var_at_min(:)
real(rp) merit, merit_at_min

integer i, j, k, n
integer n_data, n_var

logical :: abort_detected, init_needed = .true.
logical at_end

character(20) :: r_name = 'tao_lmdif_optimizer'
character(80) :: line
character(1) char

! setup

call tao_get_vars (var_value, var_delta = var_delta, var_weight = weight)
n_var = size(var_delta)
allocate (var_at_min(n_var))
var_at_min = var_value

n_data = n_var
do i = 1, size(s%u)
  if (.not. s%u(i)%is_on) cycle
  n_data = n_data + count(s%u(i)%data(:)%useit_opt .and. s%u(i)%data(:)%weight /= 0)
enddo

if (allocated(merit_vec)) deallocate(merit_vec)
allocate (merit_vec(n_data))

! run optimizer mrqmin from Numerical Recipes.

abort_detected = .false.
call initial_lmdif

merit = tao_merit()
merit_at_min = merit

call out_io (s_blank$, r_name, '   Loop      Merit')

cycle_loop: do i = 1, s%global%n_opti_cycles

  merit_vec(1:n_var) = sqrt(weight) * var_delta
  k = n_var
  do n = 1, size(s%u)
    u => s%u(n)
    if (.not. u%is_on) cycle
    do j = 1, size(u%data)
      if (.not. u%data(j)%useit_opt) cycle
      if (u%data(j)%weight == 0) cycle
      k = k + 1
      merit_vec(k) = sqrt(u%data(j)%weight) * u%data(j)%delta_merit
    enddo
  enddo

  call suggest_lmdif (var_value, merit_vec, s%global%lmdif_eps, s%global%n_opti_cycles, at_end)
  call tao_set_vars (var_value)
  merit = tao_merit()
  if (merit < merit_at_min) then
    merit_at_min = merit
    var_at_min = var_value
  endif
  write (line, '(i5, es14.4, es10.2)') i, merit
  call out_io (s_blank$, r_name, line)

  if (at_end) exit

#ifndef CESR_WINCVF
  ! look for keyboard input to end optimization

  do
    call get_tty_char (char, .false., .false.) 
    if (char == '.') then
      abort_detected = .true.
      call out_io (s_blank$, r_name, line)
      call out_io (s_blank$, r_name, 'Optimizer stop signal detected.', &
                                                             'Stopping now.')
      exit cycle_loop
    endif
    if (char == achar(0)) exit   ! only exit if there is no more input
  enddo
#endif

enddo cycle_loop

! cleanup

if (.not. abort_detected .and. i < s%global%n_opti_cycles) then
  call out_io (s_blank$, r_name, 'Optimizer at minimum. Stopping now.')
endif

if (merit > merit_at_min) then
  call out_io (s_blank$, r_name, 'Setting to minimum.')
  call tao_set_vars (var_at_min)
  merit = tao_merit()
  write (line, '(i5, es14.4, es10.2)') i, merit
endif

s%global%optimizer_running = .false.
call tao_var_write (s%global%var_out_file)
deallocate (var_at_min)

end subroutine


