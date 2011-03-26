#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin



##################################################
##						                        ##
##	         Lucid Information Systems 	        ##
##						                        ##
##	       Ensure Disk Image is not Mounted     ##
##      	         (C)2008                    ##
##						                        ##
##	              Version 0.0.4 	            ##
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
##	      The developer of this software	    ## 
##    maintains rights as specified in the      ##
##   Lucid Terms and Conditions availible from  ##
##            www.lucidsystems.org     		    ##
##                                              ##
##################################################     



# Configuration
local_image="/path/to/my_backup.sparsebundle"

# Check to see if the image is availible (provides additional details even if redundant)
if ! [ -e "${local_image}" ] ; then
    echo "    ERROR! : Disk image was not available." | tee -ai $logFile
	exit ${SCRIPT_HALT}
fi

# Check to see if the image is mounted (remotely)
# Note : This is implimentiation is dependent upon exception being raised by hdiutil
#        some mount points may not support features required to raise the exceptions.
hdiutil imageinfo "${local_image}" 1> /dev/null 2> /dev/null
if [ $? != 0 ] ; then 
	echo "    ERROR! : Disk image is mounted or is not available." | tee -ai $logFile
	exit ${SCRIPT_HALT}
fi

# Check to see if the image is mounted (locally)
hdiutil_mounted_status=`hdiutil info | grep "image-path" | grep "${local_image}"`

if [ -e "${local_image}" ] && [ "${hdiutil_mounted_status}" == "" ] ; then 
	exit ${SCRIPT_SUCCESS}	
else
	echo "    ERROR! : Disk image is mounted or is not available." | tee -ai $logFile
	exit ${SCRIPT_HALT}
fi

	


