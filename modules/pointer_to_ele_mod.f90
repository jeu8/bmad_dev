module pointer_to_ele_mod

use equal_mod

implicit none

private pointer_to_ele1, pointer_to_ele2

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_ele (...)
!
! Routine to return a pointer to an element.
! pointer_to_ele is an overloaded name for:
!     Function pointer_to_ele1 (lat, ix_ele, ix_branch) result (ele_ptr)
!     Function pointer_to_ele2 (lat, ele_loc_id) result (ele_ptr)
!     Function pointer_to_ele3 (lat, ele_name) result (ele_ptr)
!
! Note that using ele_name to locate an element is potentially dangerous if there
! are multiple elements that have the same name. Better in this case is to use:
!   lat_ele_locator
!
! Also see:
!   pointer_to_slave
!   pointer_to_lord
!
! Input:
!   lat       -- lat_struct: Lattice.
!   ix_ele    -- Integer: Index of element in lat%branch(ix_branch)
!   ix_branch -- Integer: Index of the lat%branch(:) containing the element.
!   ele_loc   -- Lat_ele_loc_struct: Location identification.
!   ele_name  -- character(*): Name or index of element.
!
! Output:
!   ele_ptr  -- Ele_struct, pointer: Pointer to the element. 
!-

interface pointer_to_ele
  module procedure pointer_to_ele1
  module procedure pointer_to_ele2
  module procedure pointer_to_ele3
end interface

contains

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_ele1 (lat, ix_ele, ix_branch) result (ele_ptr)
!
! Function to return a pointer to an element in a lattice.
! This routine is overloaded by pointer_to_ele.
! See pointer_to_ele for more details.
!-

function pointer_to_ele1 (lat, ix_ele, ix_branch) result (ele_ptr)

type (lat_struct), target :: lat
type (ele_struct), pointer :: ele_ptr

integer ix_branch, ix_ele

!

ele_ptr => null()

if (ix_branch < 0 .or. ix_branch > ubound(lat%branch, 1)) return
if (ix_ele < 0 .or. ix_ele > lat%branch(ix_branch)%n_ele_max) return

ele_ptr => lat%branch(ix_branch)%ele(ix_ele)

end function pointer_to_ele1

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_ele2 (lat, ele_loc) result (ele_ptr)
!
! Function to return a pointer to an element in a lattice.
! This routine is overloaded by pointer_to_ele.
! See pointer_to_ele for more details.
!-

function pointer_to_ele2 (lat, ele_loc) result (ele_ptr)

type (lat_struct), target :: lat
type (ele_struct), pointer :: ele_ptr
type (lat_ele_loc_struct) ele_loc

!

ele_ptr => null()

if (ele_loc%ix_branch < 0 .or. ele_loc%ix_branch > ubound(lat%branch, 1)) return
if (ele_loc%ix_ele < 0 .or. ele_loc%ix_ele > lat%branch(ele_loc%ix_branch)%n_ele_max) return

ele_ptr => lat%branch(ele_loc%ix_branch)%ele(ele_loc%ix_ele)

end function pointer_to_ele2

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_ele3 (lat, ele_name) result (ele_ptr)
!
! Function to return a pointer to an element in a lattice.
! This routine is overloaded by pointer_to_ele.
! See pointer_to_ele for more details.
!-

function pointer_to_ele3 (lat, ele_name) result (ele_ptr)

type (lat_struct), target :: lat
type (ele_struct), pointer :: ele_ptr
type (ele_pointer_struct), allocatable :: eles(:)

integer n_loc
logical err

character(*) ele_name

!

ele_ptr => null()

call lat_ele_locator (ele_name, lat, eles, n_loc, err)
if (n_loc == 0) return

ele_ptr => eles(1)%ele

end function pointer_to_ele3

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! function pointer_to_field_ele(ele, ix_field_ele, dz_offset) result (field_ele)
!
! Routine to return a pointer to one of the "field elements" associated with a given element.
!
! A "field element" associated with a given element is an element that field info for the given element. 
! For example: a slice_slave of a super_slave of a multipass_slave will have its field info
! stored in the multipass_lord.
!
! The number of associated field elements can be determined by the routine num_field_eles.
!
! Note: groups, overlays, and girders will never have field info.
! Note: An element like a quadrupole with no lords will have one associated field element which is itself.
!
! Input:
!   ele           -- ele_struct: Element with sum number of associated field elements.
!   ix_field_ele  -- integer: Index of the field element to point to. This index runs from
!                     1 to num_field_eles(ele).
!
! Output:
!   field_ele     -- ele_struct: Pointer to the field element with index ix_field_ele.
!                     Will point to null if ix_field_ele is out of range.
!   dz_offset     -- real(rp), optional: Longitudinal offset of ele from the field ele pointed to.
!-

function pointer_to_field_ele(ele, ix_field_ele, dz_offset) result (field_ele)

implicit none

type (ele_struct), target :: ele
type (ele_struct), pointer :: field_ele, fele
integer ix_field_ele, ix
real(rp), optional :: dz_offset
real(rp) offset

!

nullify(field_ele)
if (ix_field_ele < 1) return

ix = 0
offset = 0
call iterate_over_field_eles(ele, ix, ix_field_ele, field_ele, offset)
if (present(dz_offset)) dz_offset = offset

!---------------------------------------
contains

recursive subroutine iterate_over_field_eles(ele, ixf, ix_field_ele, field_ele, offset)

type (ele_struct), target :: ele
type (ele_struct), pointer :: this_ele, field_ele
real(rp) offset
integer ixf, ix_field_ele, i

select case (ele%key)
case (overlay$, group$, girder$, null_ele$); return
end select

if (ele%field_calc == refer_to_lords$) then
  do i = 1, ele%n_lord
    this_ele => pointer_to_lord(ele, i)

    select case (this_ele%key)
    case (overlay$, group$, girder$); cycle
    end select

    offset = offset + ele%s_start - this_ele%s_start
    call iterate_over_field_eles (this_ele, ixf, ix_field_ele, field_ele, offset)
    if (associated(field_ele)) return
  enddo

else
  ixf = ixf + 1
  if (ixf /= ix_field_ele) return
  field_ele => ele
endif

end subroutine iterate_over_field_eles

end function pointer_to_field_ele

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function num_field_eles (ele) result (n_field_ele)
!
! Routine to return the number of field elements associated with a given element.
! n_field_ele will be zero for groups, overlays, and girders.
!
! See the routine pointer_to_field_ele for more info.
!
! Input:
!   ele       -- ele_struct: Element with sum number of associated field elements.
!
! Output:
!   n_field_ele -- integer: Number of associated field elements.
!-

function num_field_eles (ele) result (n_field_ele)

implicit none

type (ele_struct) ele
type (ele_struct), pointer :: f_ele
integer n_field_ele

!

n_field_ele = 0

do
  n_field_ele = n_field_ele + 1
  f_ele => pointer_to_field_ele(ele, n_field_ele)
  if (.not. associated(f_ele)) exit
enddo

n_field_ele = n_field_ele - 1

end function num_field_eles

end module
