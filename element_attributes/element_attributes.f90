!+
! Program: element_attributes
!
! Program to print which element attributes are defined for different types of elements.
! This is useful when new attributes need to be defined for a given element type.
! Generally only Bmad wizards are interested in this.
!-

program element_attributes

use bmad

implicit none

type (ele_struct) ele
integer i, j, n_used(n_attrib_special_maxx)
character(40) a_name

!

n_used = 0

do i = 1, n_key
  print *, '!---------------------------------'
  print *, key_name(i)
  ele%key = i
  do j = 1, n_attrib_special_maxx
    a_name = attribute_name (ele, j) 
    if (a_name(1:1) == '!') cycle
    print '(i10, 2x, a)', j, a_name
    n_used(j) = n_used(j) + 1
  enddo
  print *
enddo

print *, '!---------------------------------'
print *, 'Index usage:'
print *, '   Ix Count'
do i = 1, size(n_used)
  print '(2i6)', i, n_used(i)
enddo

end program
