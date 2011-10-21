#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin

##################################################
##						                        ##
##	       Lucid Information Systems 	        ##
##						                        ##
##	                 OpenLog                    ##
##      	         (C)2008                    ##
##						                        ##
##		           Version 0.0.1 	            ##
##                                              ##
##          Developed by Henri Shustak          ##
##                                              ##
##        This software is licenced under 	    ##
##      the GNU GPL. This software may only  	##
##            be used or installed or 		    ##
##          distributed in accordance       	##
##              with this licence.              ##
##                                              ##
##           Lucid Inormatin Systems.           ##
##						                        ##
##	     The developer of this software	        ##
##    maintains rights as specified in the      ##
##   Lucid Terms and Conditions availible from  ##
##            www.lucidsystems.org     		    ##
##                                              ##
##################################################

#
#  This is a simple script which opens the log file
#  Note : Someone must be logged in for this script
#         to work.
#

###############################
####     PERFROM ACTION     ###
###############################

open $logFile

exit ${SCRIPT_SUCCESS}

