!+
! Subroutine tao_help (help_what)
!
! Online help for TAO commmands. 
! Interfaces with the documentation.
!
! Input:
!   help_what   -- Character(*): command to query
!
! Output:
!   none
!
!-

subroutine tao_help (help_what)

use tao_struct
use tao_interface
use cesr_utils

implicit none

integer nl, iu, ios, n, ix, ix2

character(*) :: help_what
character(16) :: r_name = "TAO_HELP"
character(40) start_tag
character(200) line, file_name

logical blank_line_before

! Help depends upon if we are in single mode or not.
! Determine what file to open and starting tag.

if (tao_com%single_mode) then
  call fullfilename ('TAO_DIR:doc/single-mode.tex', file_name)
else
  call fullfilename ('TAO_DIR:doc/command-list.tex', file_name)
endif

if (help_what == '') then
  start_tag = '%% command_table'
else
  start_tag = '%% ' // help_what
endif

! Open the file 

iu = lunget()
open (iu, file = file_name, iostat = ios)
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT OPEN FILE: ' // file_name)
  return
endif

! Skip all lines before the start tag.

n = len_trim(start_tag)
do 
  read (iu, '(a)', iostat = ios) line
  if (ios /= 0) then
    call out_io (s_error$, r_name, 'CANNOT FIND TAG: ' // start_tag, &
                                                     'IN FILE: ' // file_name)
    return
  endif
  if (line(1:n) == start_tag(1:n)) exit
enddo

! Print all lines to the next tag or the end of the file.

if (help_what == '') then
  call out_io (s_blank$, r_name, &
                 "Type 'help <command>' for help on an individual command", &
                 "Available commands:")
endif

blank_line_before = .true.
do
  read (iu, '(a)', iostat = ios) line
  if (ios /= 0) return
  if (line(1:2) == '%%') return

  if (line(1:8)  == '\section')   cycle
  if (line(1:6)  == '\label')     cycle
  if (line(1:6)  == '\begin')     cycle
  if (line(1:4)  == '\end')       cycle
  if (line(1:10) == '\centering') cycle
  if (line(1:8)  == '\caption') cycle
  
  if (line(1:6)  == '\vskip') then
    call string_trim (line(7:), line, ix)
    call string_trim (line(ix+1:), line, ix)
  endif

  call substitute ("``", '"')
  call substitute ("''", '"')
  call substitute ("$")
  call substitute ("\{", "{")
  call substitute ("\}", "}")
  call substitute ("\_", "_")
  call substitute ("\tao", "Tao")
  call eliminate2 ('\item[', ']')
  call eliminate2 ('\vn{', '}', '"', '"')
  call eliminate_inbetween ('& \sref{', '}', .true.)
  call eliminate_inbetween ('\sref{', '}', .false.)
  call eliminate_inbetween ('{\it ', '}', .false.)
  call substitute (" &")
  call substitute ('\\ \hline')
  call substitute ('\W ', '^')
  call substitute ('"\W"', '"^"')
  
  if (line == ' ') then
    if (blank_line_before) cycle
    blank_line_before = .true.
  else
    blank_line_before = .false.
  endif

  call out_io (s_blank$, r_name, line)

enddo

!-----------------------------------------------------------------------------
contains
!
! substitutes a string and optionally replaces it with another

subroutine substitute (str1, sub)

character(*) str1
character(*), optional :: sub
integer n1

!

n1 = len(str1)

do
  ix = index(line, str1)
  if (ix == 0) exit
  if (present(sub)) then
    line = line(1:ix-1) // sub // line(ix+n1:)
  else
    line = line(1:ix-1) // line(ix+n1:)
  endif
enddo

end subroutine


!-----------------------------------------------------------------------------
! contains
!
! eliminates two strings, but only if they both exist on the same line

subroutine eliminate2 (str1, str2, sub1, sub2)

character(*) str1, str2
character(*), optional :: sub1, sub2
integer n1, n2

n1 = len(str1)
n2 = len(str2)

do
  ix = index (line, str1)
  if (ix == 0) return
  ix2 = index (line(ix+1:), str2) + ix
  if (ix2 == 0) return
  if (present(sub1)) then
    line = line(1:ix-1) // sub1 // line(ix+n1:ix2-1) // sub2 // line(ix2+n2:)    
  else
    line = line(1:ix-1) // line(ix+n1:ix2-1) // line(ix2+n2:)
  endif
enddo

end subroutine

!-----------------------------------------------------------------------------
! contains
!
! eliminates everything between strings, including the strings

subroutine eliminate_inbetween (str1, str2, pad_with_blanks)

character(*) str1, str2
character(100) :: blank = ''

integer n1, n2

logical pad_with_blanks

!

n1 = len(str1)
n2 = len(str2)

do
  ix = index (line, str1)
  if (ix == 0) return
  ix2 = index (line(ix+1:), str2) + ix
  if (ix2 == 0) return
  if (pad_with_blanks) then
    line = line(1:ix-1) // blank(:ix2+n2-ix) // line(ix2+n2:)
  else
    line = line(1:ix-1) // line(ix2+n2:)
  endif
enddo

end subroutine

end subroutine tao_help
