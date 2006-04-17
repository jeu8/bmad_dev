module tao_set_mod

use tao_mod
use quick_plot
use tao_lattice_calc_mod

contains

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
! Subroutine tao_set_lattice_cmd (set_lattice, to_lattice)
!
! Sets a lattice equal to another. This will also update the data structs
! If the 
!
! Input:
!   set_lattice -- Character(*): Maybe: 'model', 'design', or 'base' with 
!                     optional ';n' at end to indicate the universe
!   to_lattice  -- Character(*): Maybe: 'model', 'design', or 'base' 
!
!  Output:
!    s%u(n) -- ring_struct: changes specified lattice in specified universe 
!-

subroutine tao_set_lattice_cmd (set_lattice, to_lattice)

implicit none

character(*) set_lattice, to_lattice
character(16) set_lat_name
character(20) :: r_name = 'tao_set_lattice_cmd'

integer i

logical, automatic :: this_u(size(s%u))
logical err

call tao_pick_universe (set_lattice, set_lat_name, this_u, err)
if (err) return

do i = 1, size(s%u)
  if (.not. this_u(i)) cycle
  call set_lat (s%u(i))
  if (err) return
enddo

!-------------------------------------------
contains

subroutine set_lat (u)

implicit none

type (tao_universe_struct), target :: u
type (tao_lattice_struct), pointer :: set_this_lat
type (tao_lattice_struct), pointer :: to_this_lat
real(rp), pointer :: set_this_data(:)
real(rp), pointer :: to_this_data(:)
logical calc_ok

!

err = .false.

select case (set_lat_name)
  case ('model')
    set_this_lat => u%model
    set_this_data => u%data%model_value
  case ('base')
    set_this_lat => u%base
    set_this_data => u%data%base_value
  case ('design')
    set_this_lat => u%design
    set_this_data => u%data%design_value
  case default
    call out_io (s_error$, r_name, 'BAD LATTICE: ' // set_lattice)
    err = .true.
    return
end select

select case (to_lattice)
  case ('model')
    ! make sure model data is up to date
    s%global%lattice_recalc = .true.
    call tao_lattice_calc (calc_ok)
    to_this_lat => u%model
    to_this_data => u%data%model_value
  case ('base')
    to_this_lat => u%base
    to_this_data => u%data%base_value
  case ('design')
    to_this_lat => u%design
    to_this_data => u%data%design_value
  case default
    call out_io (s_error$, r_name, 'BAD LATTICE: ' // to_lattice)
    err = .true.
    return
end select
  
set_this_lat%lat = to_this_lat%lat
set_this_lat%orb = to_this_lat%orb
set_this_lat%modes = to_this_lat%modes

set_this_data = to_this_data

end subroutine set_lat

end subroutine tao_set_lattice_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_global_cmd (who, set_value)
!
! Routine to set global variables
! 
! Input:
!   who       -- Character(*): which global variable to set
!   set_value -- Character(*): Value to set to.
!
! Output:
!    %global  -- Global variables structure.
!-

subroutine tao_set_global_cmd (who, set_value)

implicit none

type (tao_global_struct) global

character(*) who, set_value
character(20) :: r_name = 'tao_set_global_cmd'

integer iu, ios

namelist / params / global

! open a scratch file for a namelist read

iu = lunget()
open (iu, status = 'scratch')
write (iu, *) '&params'
write (iu, *) ' global%' // trim(who) // ' = ' // trim(set_value)
write (iu, *) '/'
rewind (iu)
global = s%global  ! set defaults
read (iu, nml = params, iostat = ios)
close (iu)

if (ios == 0) then
  s%global = global
  if (trim(who) .eq. 'track_type') s%global%lattice_recalc = .true.
else
  call out_io (s_error$, r_name, 'BAD COMPONENT OR NUMBER')
endif

end subroutine tao_set_global_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
! Subroutine tao_set_plot_page_cmd (component, set_value)
!
!  Set various aspects of the plotting window
!
! Input:
!   component     -- Character(*): Which component to set.
!   set_value     -- Character(*): What value to set to.
!
!  Output:
!    s%plot_page  -- tao_plot_page_struct:
!-

subroutine tao_set_plot_page_cmd (component, set_value1, set_value2)

implicit none

character(*) component, set_value1
character(*), optional :: set_value2
character(20) :: r_name = 'tao_set_plot_page_cmd'

real(rp) x, y
integer ix

select case (component)

  case ('title')
    s%plot_page%title(1)%string = trim(set_value1)

  case ('subtitle')
    s%plot_page%title(2)%string = trim(set_value1)
    s%plot_page%title(2)%draw_it = .true.

  case ('subtitle_loc')
    
    if (.not. present(set_value2)) then
      call out_io(s_info$, r_name, "subtitle_loc requires two numbers.")
      return
    endif
    
    read(set_value1, '(f15.10)') x
    read(set_value2, '(f15.10)') y
    s%plot_page%title(2)%x = x
    s%plot_page%title(2)%y = y

end select

end subroutine tao_set_plot_page_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_curve_cmd (curve_name, component, set_value)
!
! Routine to set var values.
!
! Input:
!   curve_name -- Character(*): Which curve to set.
!   component  -- Character(*): Which component to set.
!   set_value  -- Character(*): What value to set it to.
!-

subroutine tao_set_curve_cmd (curve_name, component, set_value)

implicit none

type (tao_curve_struct), pointer :: curve

integer i, ios, i_uni
integer, allocatable :: ix_ele(:)

character(*) curve_name, component, set_value
character(20) :: r_name = 'tao_set_curve_cmd'

logical err

!

call tao_find_plot_by_region (err, curve_name, curve = curve)
if (err) return
if (.not. associated(curve)) then
  call out_io (s_error$, r_name, 'CURVE NOT SPECIFIED')
  return
endif

i_uni = curve%ix_universe
if (i_uni == 0) i_uni = s%global%u_view

select case (component)

  case ('ele_ref_name')
    curve%ele_ref_name = set_value
    call tao_locate_element (curve%ele_ref_name, i_uni, ix_ele, .true.)
    curve%ix_ele_ref = ix_ele(1)

  case ('ix_ele_ref')
    read (set_value, '(i)', iostat = ios) i
    if (ios /= 0) then
      call out_io (s_error$, r_name, 'BAD IX_ELE_REF VALUE')
      return
    endif
    curve%ix_ele_ref = i      
    curve%ele_ref_name = s%u(i_uni)%model%lat%ele_(curve%ix_ele_ref)%name

  case default
    
    call out_io (s_error$, r_name, "BAD CURVE COMPONENT")
    return
    
end select

s%global%lattice_recalc = .true.

end subroutine

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_graph_cmd (name, component, set_value)
!
! Routine to set var values.
!
! Input:
!   name       -- Character(*): Which graph to set.
!   component  -- Character(*): Which component to set.
!   set_value  -- Character(*): What value to set it to.
!
!  Output:
!-

subroutine tao_set_graph_cmd (name, component, set_value)

implicit none

character(*) name, component, set_value
character(20) :: r_name = 'tao_set_graph_cmd'

logical err

! Locate the graph

print *, 'Not yet implemented'



end subroutine

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_var_cmd (var_str, set_str)
!
! Routine to set var values.
!
! Input:
!   var_str  -- Character(*): Which var name to set.
!   set_str  -- Character(*): What value to set it to.
!
!  Output:
!-

subroutine tao_set_var_cmd (var_str, set_str)

implicit none

type (tao_v1_var_struct), pointer :: v1_ptr
type (tao_real_array_struct), allocatable, save    :: r_dat(:), r_set(:)
type (tao_logical_array_struct), allocatable, save :: l_dat(:), l_set(:)
type (tao_var_array_struct), allocatable, save     :: v_array(:)

real(rp), allocatable :: r_value(:)
real(rp) value
integer i, j

character(*) var_str, set_str
character(20) :: r_name = 'tao_set_var_cmd'
character(20) set_is, component

logical err, l_value, err_flag

! Decode set_str.
! It might be a number or it might be a datum value.

if (is_logical(set_str)) then
  read (set_str, *) l_value
  set_is = 'LOGICAL-SCALER'
else
  call tao_find_var (err, set_str, &
                r_array=r_set, l_array=l_set, print_err = .false.)
  if (allocated(l_set)) then
    set_is = 'LOGICAL-VECTOR'
  else
    set_is = 'REAL'
    call tao_to_real_vector (set_str, r_value, err_flag)
    if (err_flag) then
      call out_io (s_error$, r_name, 'BAD SET VALUE ' // set_str)
      return
    endif
  endif
endif

! select value and set.

call tao_find_var (err, var_str, v_array = v_array, r_array=r_dat, &
                                    l_array=l_dat, component = component)
if (err) return

if (allocated(r_dat)) then
  if (set_is /= 'REAL') then
    call out_io (s_error$, r_name, 'BAD: REAL = LOGICAL: ' // &
                                          var_str // ' = ' // set_str)
    return
  endif

  if (size(r_value) > 1 .and. size(r_dat) /= size(r_value)) then
    call out_io (s_error$, r_name, 'ARRAY SIZE MISMATCH: ' // &
                                          var_str // ' = ' // set_str)
    return
  endif

  do i = 1, size(r_dat)
    if (size(r_value) == 1) then
      value = r_value(1)
    else
      value = r_value(i)
    endif
    r_dat(i)%r = value
    if (component == 'model') call tao_set_var_model_value (v_array(i)%v, value)
  enddo

!

elseif (allocated(l_dat)) then
  if (set_is(1:7) /= 'LOGICAL') then
    call out_io (s_error$, r_name, 'BAD: LOGICAL = REAL: ' // &
                                          var_str // ' = ' // set_str)
  endif

  do i = 1, size(l_dat)
    if (set_is == 'LOGICAL-SCALER') then
      l_dat(i)%l = l_value
    elseif (set_is == 'LOGICAL-VECTOR') then
      if (size(l_set) == 1) then
        l_dat(i)%l = l_set(1)%l
      elseif (size(l_set) == size(l_dat)) then
        l_dat(i)%l = l_set(i)%l
      else
        call out_io (s_error$, r_name, 'ARRAY SIZE MISMATCH: ' // &
                                          var_str // ' = ' // set_str)
        return
      endif   
    endif 
  enddo

else
  call out_io (s_error$, r_name, 'BAD DATA NAME ' // var_str)
endif

end subroutine tao_set_var_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_data_cmd (data_str, set_str)
!
! Routine to set data values.
!
! Input:
!   data_str -- Character(*): Which data name to set.
!   set_str  -- Character(*): What value to set it to.
!
!  Output:
!-

subroutine tao_set_data_cmd (data_str, set_str)

implicit none

type (tao_real_array_struct), allocatable, save    :: r_dat(:), r_set(:)
type (tao_logical_array_struct), allocatable, save :: l_dat(:), l_set(:)

real(rp), allocatable :: r_value(:)
integer i

character(*) data_str, set_str
character(20) set_is
character(20) :: r_name = 'tao_set_data_cmd'

logical err, l_value

! Decode set_str.
! It might be a number or it might be a datum value.

if (is_logical(set_str)) then
  read (set_str, *) l_value
  set_is = 'LOGICAL-SCALER'
else
  call tao_find_data (err, set_str, &
                r_array=r_set, l_array=l_set, print_err = .false.)
  if (allocated(l_set)) then
    set_is = 'LOGICAL-VECTOR'
  else
    set_is = 'REAL'
    call tao_to_real_vector (set_str, r_value, err)
    if (err) then
      call out_io (s_error$, r_name, 'BAD SET VALUE ' // set_str)
      return
    endif
  endif
endif

! select value and set.

call tao_find_data (err, data_str, r_array=r_dat, l_array=l_dat)
if (err) return

if (allocated(r_dat)) then
  if (set_is /= 'REAL') then
    call out_io (s_error$, r_name, 'BAD: REAL = LOGICAL: ' // &
                                          data_str // ' = ' // set_str)
    return
  endif

  if (size(r_value) > 1 .and. size(r_dat) /= size(r_value)) then
    call out_io (s_error$, r_name, 'ARRAY SIZE MISMATCH: ' // &
                                          data_str // ' = ' // set_str)
    return
  endif

  do i = 1, size(r_dat)
    if (size(r_value) == 1) then
      r_dat(i)%r = r_value(1)
    else
      r_dat(i)%r = r_value(i)
    endif
  enddo

!

elseif (allocated(l_dat)) then
  do i = 1, size(l_dat)
    if (set_is == 'LOGICAL-SCALER') then
      l_dat(i)%l = l_value
    elseif (set_is == 'LOGICAL-VECTOR') then
      if (size(l_set) == 1) then
        l_dat(i)%l = l_set(1)%l
      elseif (size(l_set) == size(l_dat)) then
        l_dat(i)%l = l_set(i)%l
      else
        call out_io (s_error$, r_name, 'ARRAY SIZE MISMATCH: ' // &
                                          data_str // ' = ' // set_str)
        return
      endif    
    else
      call out_io (s_error$, r_name, 'BAD: LOGICAL = REAL: ' // &
                                          data_str // ' = ' // set_str)
    endif
  enddo

else
  call out_io (s_error$, r_name, 'BAD DATA NAME ' // data_str)
endif

end subroutine tao_set_data_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_uni_cmd (uni, on_off, recalc)
!
! turns a universe of or off
!
! Input:
!  uni       -- Integer: which universe; 0 => all off (if you really want to)
!  on_off    -- Character(*): "on" or "off"
!  recalc    -- Logical: Recalculate lattices
!
! Output:
!  s%u(uni)%is_on
!
!-

subroutine tao_set_uni_cmd (uni, on_off, recalc)

implicit none

integer uni, i

character(*) on_off
character(20) :: r_name = "tao_set_universe_cmd"

logical is_on, recalc

  call str_upcase (on_off, on_off)

  if (on_off(1:2) .eq. 'ON') then
    is_on = .true.
  elseif (on_off(1:3) .eq. 'OFF') then
    is_on = .false.
  else
    call out_io (s_warn$, r_name, &
                 "Syntax Error: Can only turn universe 'on' or 'off'")
    return
  endif

  if (uni .lt. 0 .or. uni .gt. size(s%u)) then
    call out_io (s_warn$, r_name, &
                 "Invalid Universe specifier")
    return
  endif
  
  if (uni .eq. 0) then
    call out_io (s_blank$, r_name, &
        "Changing all universes!")
    s%u(:)%is_on = is_on
  else
    s%u(uni)%is_on = is_on
  endif

  ! make sure lattice calculation is up to date if turning lattice on
  if (recalc) s%global%lattice_recalc = .true.
  
end subroutine tao_set_uni_cmd


end module tao_set_mod
