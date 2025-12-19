#! /usr/bin/env python3
# -*- coding: utf-8 -*-

##################################################
##                                              ##
##            Lucid Information Systems         ##
##                                              ##
##               LOCAL BACKUP SCRIPT            ##
##                    (C)2005                   ##
##                                              ##
##         Developed by Samuel Williams         ##
##              and Henri Shustak               ##
##                                              ##
##        This software is licenced under       ##
##      the GNU GPL. This software may only     ##
##            be used or installed or           ##
##          distributed in accordance           ##
##              with this licence.              ##
##                                              ##
##           Lucid Inormatin Systems.           ##
##                                              ##
##        The developer of this software        ##
##    maintains rights as specified in the      ##
##   Lucid Terms and Conditions availible from  ##
##            www.lucidsystems.org              ##
##                                              ##
##################################################

# version 1.0 - initial release
# version 1.1 - updated to work with python3

import sys, base64
base64.encode(sys.stdin.buffer, sys.stdout.buffer)

