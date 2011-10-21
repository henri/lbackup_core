#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


##################################################
##						                        ##
##	         Lucid Information Systems   	    ##
##						                        ##
##	         Reports The Current Time           ##
##      	         (C)2009         		    ##
##						                        ##
##		          Version 0.0.1              	##
##                                              ##
##           Developed by Henri Shustak         ##
##                                              ##
##        This software is licensed under 	    ##
##                  the GNU GPL.                ##
##					                            ##
##	   The developer of this software           ##
##     maintains rights as specified in the     ##
##   Lucid Terms and Conditions available from  ##
##         http://www.lucidsystems.org     	    ##
##                                              ##
##################################################

#
#  This script is part of the LBackup project.
#  LBackup Home : http://www.lucidsystems.org/lbackup
#  Related Page : https://connect.homeunix.com/lbackup/example_scripts
#


time_and_date=`date`
echo "        Backup Completed : ${time_and_date}" | tee -ai $logFile


exit ${SCRIPT_SUCCESS}




