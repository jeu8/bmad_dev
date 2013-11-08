program xraylib_test

use xraylib_interface
use xraylib, dummy => r_e

implicit none

type (lat_struct), target :: lat
type (ele_struct), pointer :: ele

integer i, ix, n

character (kind=c_char, len=nist_list_string_length), pointer :: nistcompounds(:)
character(60) compound, out_str

logical err_flag

!

open (1, file = 'output.now')

!


out_str = '"OK"'

nistCompounds => GetCompoundDataNISTList()
do i = 1, size(nistcompounds)
  compound = nistcompounds(i)
  call upcase_string(compound)
  ix = index(compound, '(');  if (ix /= 0) compound = compound(1:ix-1) // compound(ix+1:)
  ix = index(compound, ')');  if (ix /= 0) compound = compound(1:ix-1) // compound(ix+1:)
  ix = index(compound, ',');  if (ix /= 0) compound = compound(1:ix-1) // compound(ix+1:)
  ix = index(compound, ',');  if (ix /= 0) compound = compound(1:ix-1) // compound(ix+1:)

  n = len_trim(compound)

  do
    ix = index(compound, ' ')
    if (ix > n) exit
    compound = compound(1:ix-1) // '_' // compound(ix+1:)
  enddo

  do
    ix = index(compound, '-')
    if (ix == 0) exit
    compound = compound(1:ix-1) // '_' // compound(ix+1:)
  enddo

  do
    ix = index(compound, '/')
    if (ix == 0) exit
    compound = compound(1:ix-1) // '_' // compound(ix+1:)
  enddo

  if (i /= xraylib_nist_compound(compound) + 1) then
    out_str = '"BAD: ' // trim(compound) // '"'
    exit
  endif
enddo

write (1, '(2a)') '"Compound_Names" STR ', trim(out_str)

!

call bmad_parser ('xraylib.bmad', lat)

ele => lat%ele(1)    ! crystal
write (1, '(a, f16.10)') '"Bragg_In"   REL 1E-8', ele%value(bragg_angle_in$)
write (1, '(a, f16.10)') '"Bragg_Out"  REL 1E-8', ele%value(bragg_angle_out$)
write (1, '(a, f16.10)') '"Alpha_Ang"  REL 1E-8', ele%value(alpha_angle$)
write (1, '(a, f16.10)') '"F0_Re"      REL 1E-8', ele%value(f0_re$)
write (1, '(a, f16.10)') '"F0_Im"      REL 1E-8', ele%value(f0_im$)
write (1, '(a, es20.8)') '"FH_Re"      REL 1E-8', ele%value(fh_re$)
write (1, '(a, es20.8)') '"FH_Im"      REL 1E-8', ele%value(fh_im$)
write (1, '(a, es20.8)') '"Darwin_Sig" REL 1E-8', ele%value(darwin_width_sigma$)
write (1, '(a, es20.8)') '"Darwin_Pi"  REL 1E-8', ele%value(darwin_width_pi$)
write (1, '(a, es20.8)') '"D_Spacing"  REL 1E-8', ele%value(d_spacing$)

ele => lat%ele(2)    ! multilayer_mirror
write (1, '(a, es20.8)') '"Graze_Ang"  REL 1E-8', ele%value(graze_angle$)
write (1, '(a, es20.8)') '"V1_Cell"    REL 1E-8', ele%value(v1_unitcell$)
write (1, '(a, es20.8)') '"F0_Re1"     REL 1E-8', ele%value(f0_re1$)
write (1, '(a, es20.8)') '"F0_Im2"     REL 1E-8', ele%value(f0_im2$)

!

end program
