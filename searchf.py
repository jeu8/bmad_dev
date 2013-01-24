#!/usr/bin/env python

import os
import sys
import re

# The idea is to look for a local copy of the library to search.
# We have found a local copy when we find one specific file that we know 
# is in the library.

release_dir   = os.environ['ACC_RELEASE_DIR'] + '/'
dist_dir  = os.environ['DIST_BASE_DIR'] + '/'

class search_com_class:
  def __init__(self):
    self.found_one = False
    self.full_doc = True
    self.match_str = ''
    self.case_sensitive = False

#-----------------------------------------

def choose_path (base_dir, base_file, dist_sub_dir):
  if os.path.isfile(base_dir + base_file):                  return base_dir
  if os.path.isfile('../' + base_dir + base_file):          return '../' + base_dir
  if os.path.isfile('../../' + base_dir + base_file):       return '../../' + base_dir
  if os.path.isfile(release_dir + base_dir + base_file):    return release_dir + base_dir
  return dist_dir + dist_sub_dir + base_dir

#-----------------------------------------

def print_help_message ():
  print '''
  Usage for getf and listf:
    getf  {options} <search_string>
    listf {options} <search_string>
  Options:
     -a          # Search Numerical recipes, forest, and varies program directories as well.
     -d <dir>    # Search files in <dir> and sub-directories for matches.
     -c          # Case sensitive search.

  Standard Libraries searched:
     bmad
     sim_utils
     cesr_utils
     mpm_utils
     tao
     bmadz
'''
  sys.exit()

#-----------------------------------------

re_routine = re.compile('(subroutine|recursive subroutine|elemental subroutine|' + \
      'function|recursive function|real\(rp\) *function|' +  \
      'integer *function|logical *function|interface) ')

re_routine_name = re.compile('\w+')

def routine_here (line2, routine_name):
  match = re_routine.match(line2)
  if match:
    name_match = re_routine_name.match(line2[match.end(1):].lstrip())
    if name_match: routine_name[0] = name_match.group(0)
    return True
  else:
    return False

#-----------------------------------------

re_interface_end      = re.compile('end +interface')
re_type               = re.compile(r'type *\(')
re_module_begin       = re.compile('module')
re_module_end         = re.compile('contains')
re_parameter          = re.compile(' parameter.*::')
re_parameter1         = re.compile(r'\s*([\$\w]+)[\(-:\) ]*=')  # match to: "charge_of(-3:3) = "
re_type_interface_end = re.compile('end +(type|interface)')
re_end                = re.compile('end')
re_routine_name_here  = re.compile('subroutine|function|interface')

def search_f90 (file_name, search_com):

  re_match_str  = re.compile(search_com.match_str.lower() + '$')
  re_type_interface_match = re.compile('^(type|interface) +' + search_com.match_str.lower() + '\s') 

  found_one_in_this_file = False
  have_printed_file_name = False
  in_module_header = False
  routine_name = ['']
  blank_line_found = False

  comments = []

  f90_file = open(file_name)
  while True:
    line = f90_file.readline()
    if line == '': return
    line2 = line.lstrip().lower()
    if line2.rstrip() == '': 
      blank_line_found = True
      continue

    # Skip blank interface blocks

    if line2 == 'interface':
      while True:
        line = f90_file.readline()
        if line == '': return
        line2 = line.lstrip().lower()
        if re_interface_end.match(line2): break

    # Skip "type (" constructs and separator comments.

    if re_type.match(line2): continue
    if line2[0] == '#': continue
    if line2[0:10] == '!---------': continue   # ignore separator comment

    # In the header section of a module

    if re_module_begin.match(line2): in_module_header = True
    if re_module_end.match(line2): in_module_header = False
    
    # Search for parameters

    if in_module_header:
      if re_parameter.search(line2):
        chunks = re_parameter.split(line2)[1].split(',')
        for chunk in chunks:
          chunk_match = re_parameter1.match(chunk)
          if chunk_match:
            param = chunk_match.group(1)
            if re_match_str.match(param) or \
               (param[-1] == '$' and re_match_str.match(param[:-1])):
              search_com.found_one = True
              found_one_in_this_file = True
              if not have_printed_file_name:
                print '\nFile:', file_name
                have_printed_file_name = True
              print '    ' + line.rstrip()

      # Add to comment block if a comment

      if line2[0] == '!':
        if blank_line_found:
          comments = []
          blank_line_found = False
        if search_com.full_doc: comments.append(line)
        continue

      # Match to type or interface statement
      # These we type the whole definition

      if re_type_interface_match.match(line2):
        search_com.found_one = True
        found_one_in_this_file = True
        print '\nFile:', file_name
        if search_com.full_doc:
          for com in comments: print com.rstrip()
          print ''
          print line.rstrip()
          while True:
            line = f90_file.readline()
            if line == '': return
            line2 = line.lstrip().lower()
            print line.rstrip()
            if re_type_interface_end.match(line2): break
        else:
          print '    ', line.rstrip()
        comments = []
        continue

      # match to subroutine, function, etc.

      if routine_here(line2, routine_name):
        if re_match_str.match(routine_name[0]):
          search_com.found_one = True
          found_one_in_this_file = True
          print '\nFile:', file_name
          if search_com.full_doc:
            for com in comments: print com.rstrip()          
          else:
            print '    ', line.rstrip()

        # Skip rest of routine including contained routines

        count = 1
        while True:
          line = f90_file.readline()
          if line == '': return
          line2 = line.lstrip().lower()

          if re_end.match(line2):
            if re_routine_name_here.match(line2[4:].lstrip()):
              count -= 1
          elif routine_here(line2, routine_name):
              count += 1

          if count == 0: break

      #

      comments = []


#-----------------------------------------

re_quote            = re.compile('"|\'')

def search_c (file_name, search_com):

  found_one_in_this_file = False
  in_extended_comment = False
  blank_line_here = False
  n_curly = 0
  comments = []
  lines_after_comments = []
  function_line = ''

  c_file = open(file_name)
  while True:
    line = c_file.readline()
    if line == '': return
    line2 = line.lstrip()
    if line2.rstrip() == '':
      blank_line_here = True
      continue

    # Ignore preprocessor lines

    if line[0] == '#': continue

    # Throw out quoted substrings

    line2.replace(r'\"', '').replace(r"\'", '')
    while True:
      match = re_quote.search(line2)
      if not match: break
      char = match.group(0)      
      ix = line2.find(char, match.end(0))
      if ix == -1: break
      line2 = line2[0:match.start(0)] + line2[ix+1:]

    # Look For multiline comment "/* ... */" construct and remove if present.

    if n_curly == 0:
      if line2[0:2] == '//' or line2[0:2] == '/*' or in_extended_comment: 
        if blank_line_here:
          comments = []
          blank_line_here = False
        comments.append(line)
        lines_after_comments = []
      else:
        lines_after_comments.append(line)


    while True:
      ix_save = 0
      if in_extended_comment:
        ix = line2.find('*/')
        if ix == -1: break
        in_extended_comment = False
        line2 = line2[0:ix_save] + line2[ix+2:]
      else:
        ix = line2.find('/*')
        if ix == -1: break
        in_extended_comment = True
        ix_save = ix

    if line2[0:2] == '//': continue
    if line2.strip() == '': continue

    ix = line2.find('//')
    if ix > -1: line2 = line2[0:ix]

    # Count curly brackets

    for char in line2:

      if n_curly == 0: 
        function_line = function_line + char
        if char == ';': 
          function_line = ''
          comments = []
          lines_after_comments = []

      if char == '{':
        n_curly += 1
        if n_curly == 1:
          if search_com.case_sensitive:
            is_match = re.search(search_com.match_str + ' *(\(.*\))* *{', function_line)
          else:
            is_match = re.search(search_com.match_str + ' *(\(.*\))* *{', function_line, re.I)
          if is_match:
            search_com.found_one = True
            if search_com.full_doc:
              print '\nFile:', file_name
              for com in comments: print com.rstrip()
              for com in lines_after_comments: print com.rstrip()
            else:
              if not found_one_in_this_file: 
                print '\nFile:', file_name
                found_one_in_this_file = True
              for com in lines_after_comments: print '    ', com.rstrip()

      elif char == '}':
        n_curly -= 1
        if n_curly == 0: 
          function_line = ''
          comments = []
          lines_after_comments = []
  return

#-----------------------------------------

def search_tree (this_dir, search_com):

  # Loop over all directories

  for root, dirs, files in os.walk(this_dir):

    # Remove from searching hidden directories plus "production" and "debug" derectories
    i = 0
    while i < len(dirs):
      if dirs[i] == 'production' or dirs[i] == 'debug' or dirs[i][0] == '.': 
        del dirs[i]
      else:
        i += 1

    # Now loop over all files

    for this_file in files:
      if re.search (this_file, '#'): continue
      file_name = os.path.join(root, this_file)
      if this_file[-4:] == '.f90' or this_file[-4:] == '.inc': search_f90(file_name, search_com)
      if this_file[-4:] == '.cpp' or this_file[-2:] == '.h' or this_file[-2:] == '.c': search_c(file_name, search_com)

  # End

  return

#-----------------------------------------

def search_all (full_doc):

  search_com = search_com_class()
  search_com.found_one = False
  search_com.full_doc = full_doc

  bmad_dir          = choose_path ('bmad', '/modules/bmad_struct.f90', '')
  cesr_utils_dir    = choose_path ('cesr_utils', '/modules/cesr_utils.f90', '')
  sim_utils_dir     = choose_path ('sim_utils', '/interfaces/sim_utils.f90', '')
  mpm_utils_dir     = choose_path ('mpm_utils', '/code/butout.f90', '')
  recipes_dir       = choose_path ('recipes_f-90_LEPP', '/lib_src/nr.f90', '')
  forest_dir        = choose_path ('forest', '/code/i_tpsa.f90', '/packages')
  tao_dir           = choose_path ('tao', '/code/tao_struct.f90', '')
  bmadz_dir         = choose_path ('bmadz', '/modules/bmadz_struct.f90', '')
  nonlin_bpm_dir    = choose_path ('nonlin_bpm', '/code/nonlin_bpm_init.f90', '')
  recipes_dir       = choose_path ('recipes_f-90_LEPP', '/lib_src/nr.f90', '')
  bsim_dir          = choose_path ('bsim', '/code/bsim_interface.f90', '')
  bsim_cesr_dir     = choose_path ('bsim_cesr', '/modules/bsim_cesr_interface.f90', '')
  cesr_programs_dir = choose_path ('cesr_programs', '/bmad_to_ing_knob/bmad_to_ing_knob.f90', '')
  cesrv_dir         = choose_path ('cesrv', '/code/cesrv_struct.f90', '')
  util_programs_dir = choose_path ('util_programs', '/bmad_to_mad_and_xsif/bmad_to_mad_and_xsif.f90', '')
  examples_dir      = choose_path ('examples', '/simple_bmad_program/simple_bmad_program.f90', '')

  #-----------------------------------------------------------
  # Look for arguments

  extra_dir = ''
  search_all = False

  i = 0
  while i+1 < len(sys.argv):
    i += 1
    arg = sys.argv[i]

    if arg[0] != '-': break

    if arg == '-d':
      extra_dir = sys.argv[i+1]
      i += 1
      continue

    if arg == '-a':
      search_all = True
      continue

    if arg == '-c':
      search_com.case_sensitive = True
      continue

    if arg == '-h':
      print_help_message ()

    print '!!! UNKNOWN ARGUMENT:', arg
    print_help_message ()

  #----------------------------------------------------------
  # Search for a match.

  if i == 0 or i >= len(sys.argv): print_help_message()

  match_str_in = sys.argv[i]
  search_com.match_str = match_str_in.replace('*', '\w*') 

  if extra_dir != '':
    print 'Searching also: extra_dir\n'
    search_tree (extra_dir, search_com)

  search_tree (bmad_dir, search_com)
  search_tree (sim_utils_dir, search_com)
  search_tree (tao_dir, search_com)
  search_tree (cesr_utils_dir, search_com)
  search_tree (mpm_utils_dir, search_com)
  search_tree (bmadz_dir, search_com)

  if search_all:
    search_tree (recipes_dir, search_com)
    search_tree (forest_dir, search_com)
    search_tree (bsim_dir, search_com)
    search_tree (bsim_cesr_dir, search_com)
    search_tree (cesr_programs_dir, search_com)
    search_tree (cesrv_dir, search_com)
    search_tree (util_programs_dir, search_com)
    search_tree (examples_dir, search_com)

  if not search_com.found_one:
    print 'Cannot match String:',  match_str_in
    print 'Use "-h" command line option to list options.'
  else:
    print ''

