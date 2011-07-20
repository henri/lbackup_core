#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin



###################################################
##                                               ##
##           Lucid Information Systems           ##
##                                               ##
##  Ensure Disk Usage is Bleow a Set Percentage  ##
##                   (C)2008                     ##
##                                               ##
##	              Version 0.0.1                  ##
##                                               ##
##          Developed by Henri Shustak           ##
##                                               ##
##        This software is licenced under        ##
##      the GNU GPL. This software may only      ##
##            be used or installed or            ##
##          distributed in accordance            ##
##              with this licence.               ##
##                                               ##
##           Lucid Inormatin Systems.            ##
##                                               ##
##	      The developer of this software	     ## 
##    maintains rights as specified in the       ##
##   Lucid Terms and Conditions availible from   ##
##            www.lucidsystems.org               ##
##                                               ##
###################################################

# This script requires LBackup 0.9.8r5 later.
#
# This script will stop the backup if the destination directory
# is not available. More recent versions of LBackup will perform
# this check regardless of whether you have this pre-action script
# enabled. However, pre-action scripts are run before this check is
# performed automatically by LBackup. If you have other pre-actions
# which depend upon the backup destination directory being present
# then you may enable this pre-action to make sure the backup directory
# is present before the backup moves ahead with other pre-action scripts.


## Configuration
backupDest="${backupDest}"


## check the backup destination directory is available
if ! [ -d "${backupDest}" ]  ; then
	echo "    ERROR! : Unable to locate the backup destination directory :" | tee -ai $logFile
	echo "             $backupDest" | tee -ai $logFile
	exit ${SCRIPT_HALT}
else 
	    exit ${SCRIPT_SUCCESS}
fi 



