#!/usr/bin/python3
import string
import sys
import getopt


####################################################
#                                                  #
#                     LogCheck                     #
#                                                  #
#   performs quick check for warnings and errors   #
#                                                  #
#                                                  #
#             Lucid Infroamtion Systems            #
#                (C) Copyright 2005                #
#                                                  #
#               www.lucidsystems.org               #
#                                                  #
#           Developed by Henri Shustak             #
#                                                  #
####################################################
#
#
# version 1.0 - initial release
# version 1.1 - updated to support pythong 3
#
##########################
##    Serarch Terms     ##
##########################

parse1 = 'ERROR!'
parse2 = 'WARNING!'





##########################
##      Help File       ##
##########################


def usage():
    print('')
    print('')
    print('   LogCheck v0.1')
    print('')
    print('           (C) Copyright 2005 Lucid Infroamtion Systems, All rights reserved')
    print('')
    print('           about :')
    print("                         LogCheck will output one (1) if ether of")
    print('                         these strings : ' + parse1 + ', ' + parse2 + ' are detected')
    print('                         The output is zero (0) if neither these')
    print('                         strings are detected.')
    print('')
    print('           options :')
    print('                          -h     --help      display this help screen')
    print('                          -s     --stdin     perform log check upon standard')
    print('                          -f     --file      perform log check upon standard')
    print('')
    print('')
    print('           example :')
    print('                         (1)     logcheck.py -h'                             )
    print('                                             displays this help message')
    print('')
    print('                         (2)     cat ~/log.txt | logcheck.py -s')
    print('                                             checks the file ~/log.txt')
    print('')
    print('                         (3)     logcheck.py -f ~/log.txt')
    print('                                              checks the file ~/log.txt')
    print('')
    print('')


##########################
##  Internal Varibles   ##
##########################

# Detection Checking
seen = False

# Standard Input Type
acceptStdin = False

# File Input Type
acceptFilin = False

# File Input File Storage
filein = ''

##########################
##    Options Check     ##
##########################

try:
    opts, args = getopt.getopt(sys.argv[1:], 'f:hs', ["help", "stdin"])
except getopt.GetoptError:
    #print help information and exit:
    usage()
    sys.exit(2)
output = None
verbose = False
for o, a in opts:
    if o in ("-s", "--stdin"):
        acceptStdin = True
    if o in ("-h", "--help"):
        usage()
        sys.exit()
    if o in ("-f", "--file"):
       acceptFilin = True
       filein = a

##########################
##   Options Checking   ##
##########################



if acceptFilin and acceptStdin:
    print('     ERROR! : Only select one input source may be selected at a time')
    print('              Help is availible by typing "checklog -h"')
    sys.exit(-1)

if not ( acceptFilin or acceptStdin) :
    print('     ERROR! : At minium one input source must be selected')
    print('              Help is availible by typing "checklog -h"')
    sys.exit(-1)

##########################
##      Set Input       ##
##########################

if ( acceptStdin == True ):
    lines = sys.stdin

else:
    file = filein
    fp = open(file, 'r+')
    lines = fp.readlines()
    fp.seek(0, 0)

##########################
##   Check for Lines    ##
##########################

for line in lines:
    seen = (line.find(parse1) >= 0)
    if seen :
        print(1)
        sys.exit()
    seen = (line.find(parse2) >= 0)
    if seen :
        print(1)
        sys.exit()
print(0)

