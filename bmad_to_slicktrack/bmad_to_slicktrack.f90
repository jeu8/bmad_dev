!+
! Program to convert a Bmad lattice file to a SLICKTRACK file.
!
! Usage:
!   bmad_to_slicktrack <bmad_file_name>
!
! The output file name will be the bmad_file_name with the '.bmad' suffix
! (or whatever suffix is there) replaced by '.slick'.
!-

program bmad_to_slicktrack

use bmad
use indexx_mod

implicit none

type (lat_struct), target :: lat
type (coord_struct), allocatable :: orbit(:)
type (ele_struct), pointer :: ele
type (nametable_struct) nametab

real(rp) slick_params(3), s_start, length
integer i, ix, n_arg, slick_class, nb, nq, ne

logical end_here, added

character(200) slick_name, bmad_name
character(100) line
character(40) arg, name
character(*), parameter :: r_name = 'bmad_to_slicktrack'

!

n_arg = cesr_iargc()
bmad_name = ''

do i = 1, n_arg
  call cesr_getarg (i, arg)
  select case (arg)
  case default
    if (arg(1:1) == '-') then
      print *, 'Bad switch: ', trim(arg)
      bmad_name = ''
      exit
    else
      bmad_name = arg
    endif
  end select
enddo

if (bmad_name == '') then
  print '(a)', 'Usage: bmad_to_slicktrack <bmad_bmad_name>'
  stop
endif

call file_suffixer (bmad_name, slick_name, '.slick', .true.)
open (1, file = slick_name)

! Get the lattice

call bmad_parser (bmad_name, lat)


!------------------------------
! Write element defs

call nametable_init(nametab)

do i = 1, lat%n_ele_track
  ele => lat%ele(i)
  call find_indexx(ele%name, nametab, ix, add_to_list = .true., has_been_added = added)
  if (.not. added) cycle

  select case (ele%key)
  case (sbend$, quadrupole$)
    if (lat%ele(i+1)%name == ele%name) then  ! Element already split in MAD file
      call ele_to_slick_params(ele, slick_class, slick_params, 1.0_rp)
    else
      call ele_to_slick_params(ele, slick_class, slick_params, 0.5_rp)
    endif
    name = trim(ele%name) // 'H'
  case default
    call ele_to_slick_params(ele, slick_class, slick_params, 1.0_rp)
    name = ele%name
  end select

  if (slick_class == -1) cycle
  write (1, '(i5, 1x, a8, 3f12.8, a)') slick_class, name, slick_params, '    1   0.000000    0'
enddo

!------------------------------
! Write inserted element defs

write (1, *)
write (1, '(a)') '----------------------------------------------------------------------------'
write (1, *)

nb = 0
nq = 0

do i = 1, lat%n_ele_track
  ele => lat%ele(i)

  select case (ele%key)
  case (sbend$)
    if (lat%ele(i+1)%name == ele%name) cycle  ! Element already split in MAD file
    if (ele%select) then  ! If k1 /= 0
      if (2*i < lat%n_ele_track) then
        call write_insert_ele_def (nq, ['HC', 'VC', 'HQ', 'VQ', 'RQ', 'CQ'])    
      else
        call write_insert_ele_def (nq, ['CQ', 'RQ', 'VQ', 'HQ', 'VC', 'HC'])    
      endif
    else
      call write_insert_ele_def (nb, ['VD'])
    endif

  case (quadrupole$)
    if (lat%ele(i+1)%name == ele%name) cycle  ! Element already split in MAD file
    if (2*i < lat%n_ele_track) then
      call write_insert_ele_def (nq, ['HC', 'VC', 'HQ', 'VQ', 'RQ', 'CQ'])    
    else
      call write_insert_ele_def (nq, ['CQ', 'RQ', 'VQ', 'HQ', 'VC', 'HC'])    
    endif
  end select
enddo

write (1, '(a)') '    1 END'

!------------------------------
! Write lattice

write (1, *)
write (1, '(a)') '----------------------------------------------------------------------------'
write (1, *)

nb = 0
nq = 0
ne = 0

do i = 1, lat%n_ele_track
  ele => lat%ele(i)

  select case (ele%key)
  case (sbend$)
    if (lat%ele(i+1)%name == ele%name) cycle  ! Element already split in MAD file

    if (lat%ele(i-1)%name == ele%name) then
      s_start = lat%ele(i-1)%s_start
      length = 2 * ele%value(l$)
    else
      s_start = ele%s_start
      length = ele%value(l$)
    endif

    name = trim(ele%name) // 'H'

    if (ele%select) then  ! If k1 /= 0
      nq = nq + 1

      if (2*i < lat%n_ele_track) then
        call write_insert_ele_position (line, ne, nq, ['HC', 'VC'], s_start)
        call write_ele_position (line, ne, name, s_start + 0.25_rp * length)
        call write_insert_ele_position (line, ne, nq, ['HQ', 'VQ', 'RQ', 'CQ'], s_start + 0.5_rp * length)
        call write_ele_position (line, ne, name, s_start + 0.75_rp * length)
      else
        call write_ele_position (line, ne, name, s_start + 0.25_rp * length)
        call write_insert_ele_position (line, ne, nq, ['CQ', 'RQ', 'VQ', 'HQ'], s_start + 0.5_rp * length)
        call write_ele_position (line, ne, name, s_start + 0.75_rp * length)
        call write_insert_ele_position (line, ne, nq, ['VC', 'HC'], ele%s)
      endif
    else
      nb = nb + 1
      call write_ele_position (line, ne, name, s_start + 0.25_rp * length)
      call write_insert_ele_position (line, ne, nb, ['VD'], s_start + 0.5_rp * length)
      call write_ele_position (line, ne, name, s_start + 0.75_rp * length)
    endif

  case (quadrupole$)
    if (lat%ele(i+1)%name == ele%name) cycle  ! Element already split in MAD file

    if (lat%ele(i-1)%name == ele%name) then
      s_start = lat%ele(i-1)%s_start
      length = 2 * ele%value(l$)
    else
      s_start = ele%s_start
      length = ele%value(l$)
    endif

    name = trim(ele%name) // 'H'
    nq = nq + 1

    if (2*i < lat%n_ele_track) then
      call write_insert_ele_position (line, ne, nq, ['HC', 'VC'], s_start)
      call write_ele_position (line, ne, name, s_start + 0.25_rp * length)
      call write_insert_ele_position (line, ne, nq, ['HQ', 'VQ', 'RQ', 'CQ'], s_start + 0.5_rp * length)
      call write_ele_position (line, ne, name, s_start + 0.75_rp * length)
    else
      call write_ele_position (line, ne, name, s_start + 0.25_rp * length)
      call write_insert_ele_position (line, ne, nq, ['CQ', 'RQ', 'VQ', 'HQ'], s_start + 0.5_rp * length)
      call write_ele_position (line, ne, name, s_start + 0.75_rp * length)
      call write_insert_ele_position (line, ne, nq, ['VC', 'HC'], ele%s)
    endif

  case (solenoid$)
    call write_ele_position (line, ne, ele%name, ele%s_start)

  case (sextupole$, rfcavity$, beambeam$, hkicker$, vkicker$, kicker$)
    call write_ele_position (line, ne, ele%name, ele%s_start + 0.5_rp * ele%value(l$))
  end select
enddo

name = 'END'
call write_ele_position (line, ne, name, lat%ele(lat%n_ele_track)%s)
write (1, '(a)') line

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
contains

! Extract the element parameter valuse to be written to the slicktrack input file

subroutine ele_to_slick_params(ele, slick_class, slick_params, scale)

type (ele_struct) ele
real(rp) slick_params(3), scale
real(rp) knl(0:n_pole_maxx), tilt(0:n_pole_maxx)
integer slick_class, ix_pole_max

!

slick_params = 0
slick_class = -1
call multipole_ele_to_kt (ele, .true., ix_pole_max, knl, tilt, magnetic$, include_kicks$)

select case (ele%key)

case (sbend$)
  if (ele%value(e1$) /= 0 .or. ele%value(e2$) /= 0) then
    print *, 'Note: Bend edge angles not translated for bend: ' // trim(ele%name)
  endif
  if (ele%value(ref_tilt$) == 0) then
    if (knl(1) == 0) then
      slick_class = 2
      ele%select = .false.  ! Mark k1 = 0
    else
      slick_class = 15
      ele%select = .true.   ! Mark k1 /= 0
    endif
    slick_params = [scale*ele%value(angle$), scale*knl(1), scale*ele%value(l$)]

  else
    if (abs(abs(ele%value(ref_tilt$)) - pi/2) > 1d-6) then
      print *, 'Bend element has ref_tilt that is not +/- pi/2! ' // trim(ele%name)
    endif

    if (knl(1) == 0) then
      slick_class = 9
    else
      slick_class = 16
    endif
    slick_params = [-scale*ele%value(angle$)*sign_of(ele%value(ref_tilt$)), scale*knl(1), scale*ele%value(l$)]
  endif

case (quadrupole$)
  if (ele%value(tilt$) == 0) then
    slick_class = 3
    slick_params = [scale*knl(1), 0.0_rp, scale*ele%value(l$)]

  else
    if (abs(abs(tilt(1)) - pi/4) > 1d-6) then
      print *, 'Bend element has tilt that is not +/- pi/4! ' // trim(ele%name)
    endif
    slick_class = 4
    slick_params = [scale*knl(1)*sign_of(tilt(1)), 0.0_rp, scale*ele%value(l$)]
  endif

case (rfcavity$)
  slick_class = 5
  slick_params = [1d-9*ele%value(voltage$), 0.0_rp, 0.0_rp]

case (sextupole$)
  if (ele%value(tilt$) /= 0) then
    print *, 'Cannot translate skew sextupole: ' // trim(ele%name)
    if (ele%value(l$) == 0) return
    print *, '   Will replace with a drift'
    slick_class = 1
    slick_params = [ele%value(l$), 0.0_rp, 0.0_rp]
  endif

  slick_class = 8
  slick_params = [knl(2), 0.0_rp, ele%value(l$)]

case (solenoid$)
  slick_class = 10
  slick_params = [scale*ele%value(ks$)*ele%value(l$), 0.0_rp, scale*ele%value(l$)]

case (beambeam$)
  slick_class = 17
  slick_params = [0.0_rp, 0.0_rp, 0.0_rp]

case (hkicker$, vkicker$, kicker$)
  if (tilt(0) == 0) then
    slick_class = 6
    slick_params = [scale*knl(0), 0.0_rp, scale*ele%value(l$)]    
  else
    slick_class = 7
    slick_params = [scale*knl(0)*sign_of(tilt(0)), 0.0_rp, scale*ele%value(l$)]    
  endif

case (drift$)
  ! Ignore

case default
  print *, 'Cannot translate: ' // trim(ele%name) // ': ' // trim(key_name(ele%key))
end select

end subroutine ele_to_slick_params

!---------------------------------------------------------------------------
! contains

subroutine write_insert_ele_def (nn, names)

integer nn
integer i, j
character(*) names(:)
character(100) line
character(4) nc

!
nn = nn + 1
nc = int_str(nn)
j = len_trim(nc)

do i = 1, size(names)
  select case (names(i))
  case ('HC'); line = '    6 HC______  0.00000000  0.00000000  0.10000000    1   0.000000    0'
  case ('VC'); line = '    7 VC______  0.00000000  0.00000000  0.10000000    1   0.000000    0'
  case ('HQ'); line = '    6 HQ______  0.00000000  0.00000000  0.10000000    1   0.000000    0'
  case ('VQ'); line = '    7 VQ______  0.00000000  0.00000000  0.10000000    1   0.000000    0'
  case ('RQ'); line = '    4 RQ______  0.00000000  0.00000000  0.00000000    1   0.000000    0'
  case ('CQ'); line = '    3 CQ______  0.00000000  0.00000000  0.00000000    1   0.000000    0'
  case ('VD'); line = '    7 VD______  0.00000000  0.00000000  0.10000000    1   0.000000    0'
  end select

  line(15-j:14) = nc(1:j)
  write (1, '(a)') trim(line)
enddo


end subroutine write_insert_ele_def

!---------------------------------------------------------------------------
! contains

subroutine write_insert_ele_position (line, ne, nn, names, s)

real(rp) s
integer ne, nn
integer i, j
character(*) line, names(:)
character(8) ele_name
character(4) nc

!

do i = 1, size(names)
  ne = ne + 1
  if (ne == 5) then
    write (1, '(a)') trim(line)
    line = ''
    ne = 1
  endif

  nc = int_str(nn)
  j = len_trim(nc)
  ele_name = names(i) // '______'
  ele_name(9-j:8) = nc(1:j)

  write (line((ne-1)*22+1:), '(a, f13.6)') ele_name, s
!  write (line((ne-1)*22+1:), '(a, i12)') ele_name, nint(s*1d4)
enddo

end subroutine write_insert_ele_position

!---------------------------------------------------------------------------
! contains

subroutine write_ele_position (line, ne, name, s)

real(rp) s
integer ne
character(*) line, name

!

ne = ne + 1
if (ne == 5) then
  write (1, '(a)') trim(line)
  line = ''
  ne = 1
endif

write (line((ne-1)*22+1:), '(a, f13.6)') name(1:8), s
! write (line((ne-1)*22+1:), '(a, i12)') name(1:8), nint(s*1d4)

end subroutine write_ele_position

end program



