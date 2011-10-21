#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


######################################################
##						                            ##
##	          Lucid Information Systems 	        ##
##						                            ##
##     Sync Sparse Disk Image to Remote Server      ##
##      	           (C)2005		                ##
##						                            ##
##		            Version 0.1.5 	                ##
##                                                  ##
##            Developed by Henri Shustak            ##
##                                                  ##
##        This software is licensed under 	        ##
##                  the GNU GPL.                    ##
##						                            ##
##	     The developer of this software	            ##
##    maintains rights as specified in the          ##
##   Lucid Terms and Conditions availible from      ##
##            www.lucidsystems.org     		        ##
##                                                  ##
######################################################



# This script will use rsync to push an updated copy of a sparse bundle image
# from the local machine to a remote machine.
#
# This script could easily be modified to pull the backup or move the backup between two servers.
#
# This script is also easily condensable into a single line so it can be added concisely to your .profile
# for easy execution.
#
# The script will display progress of each band being copied or deleted during the copy. To disable this
# remove the --progress option when calling rsync.
#
# If you are syncing arcross a link then you will probably want to alter some of the settings.
#
# Finally, IT IS VERY IMPORTANT that before you call this script you check the disk image is not mounted.
# In addition, this script has only been tested between Mac OS X systems. Use it on other operating systems
# at your own risk.
#
# Do not add spaces etc into any paths. This script will probably break.



## Various settings which you will want to alter before running this script.
local_sparse_bundle_to_sync="/path/to/my_backup.sparsebundle"
remote_sparse_bundle_destination="/backups/"
remote_server_address="myremotesshserver.mydomain.com"
remote_server_user="mrbackup"
path_to_rsync="/usr/local/bin/rsync_v3.0.7"
remote_path_to_rsync="/usr/local/bin/rsync_v3.0.7"

## SSH Run As Other User Settings
# leave these blank for the user who executes the script.
# run_sync_as=otheruser
run_sync_as=

# If using an SSH agent the export command to the socket
# export_ssh_agent_command="export SSH_AUTH_SOCK=/tmp/path/to/ssh.socket"
export_ssh_agent_command=
# export SSH_AUTH_SOCK=/tmp/path/to/ssh.socket


# intenral varibles just leave alone
path_to_bash="/bin/bash"
rsync_command=""
hdiutil_mounted_status=""
local_system_kind=""
remote_system_kind=""
export_ssh_agent_command_with_colon=""

# Preflight Checks
if [ "${backup_status}" != "SUCCESS" ] ; then
    echo "    WARNING! : Sparse image synchronization will not continue because the backup has not succeeded." | tee -ai $logFile
    exit ${SCRIPT_WARNING}
fi

# If there is a value within the export_ssh_agent_command varible then populate the export_ssh_agent_command_with_colon varible
if [ "${export_ssh_agent_command}" != "" ] ; then
    export_ssh_agent_command_with_colon="${export_ssh_agent_command} ;"
fi

# More Internal Checks and varibles
hdiutil_mounted_status=`hdiutil info | grep "image-path" | grep "${local_sparse_bundle_to_sync}"`
local_system_kind=`uname`
if [ "${run_sync_as}" == "" ] ; then
    remote_system_kind=`ssh ${remote_server_user}@${remote_server_address} "uname"`
else
    remote_system_kind=`su -l ${run_sync_as} -c "${export_ssh_agent_command_with_colon} ssh ${remote_server_user}@${remote_server_address} \"uname\""`
fi


# Check this and the remote system are both Mac OS X Systems
if [ "${local_system_kind}" == "Darwin" ] && [ "${remote_system_kind}" == "Darwin" ] ; then
    # Test SSH Connection
    if [ "${run_sync_as}" == "" ] ; then
        ssh ${remote_server_user}@${remote_server_address} "##--LBackup_Sync_Sparse_Bundel_SSH_Test--## ; exit 0"
        ssh_test_result=$?
    else
        sudo su -l ${run_sync_as} -c "${export_ssh_agent_command_with_colon} ssh ${remote_server_user}@${remote_server_address} \"##--LBackup_Sync_Sparse_Bundel_SSH_Test--## ; exit 0 \""
        ssh_test_result=$?
    fi
    # Depending how critical this is you may want to halt rather than just warn.
    if [ $ssh_test_result != 0 ] ; then
        echo "    WARNING! : The remote system is not a available via SSH."  | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi
else
    if [ "${remote_system_kind}" == "" ] ; then
        # Depending how critical this is you may want to halt rather than just warn.
        echo "    WARNING! : The remote system is not a available via SSH."  | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi
    if [ "${remote_system_kind}" != "Linux" ] ; then
        # Depending how critical this is you may want to halt rather than just warn.
        echo "    WARNING! : The remote or local system is not a Mac OS X system."  | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi
    if [ "${remote_system_kind}" == "Linux" ] ; then
        # Print something out stating that the server is LINUX
        echo "    Remote system is Linux..." | tee -ai $logFile
    fi
fi




# Okay now we have all the configuration information lets copy / update the sparse bundle.

# Check the image available and is not mounted.
if [ -d "${local_sparse_bundle_to_sync}" ] && [ "${hdiutil_mounted_status}" == "" ] ; then

    # Print some volume statistics for the remote servers root partition.
    echo "    Remote server disk usage statistics for : $remote_server_address "| tee -ai $logFile
    if [ "${run_sync_as}" == "" ] ; then
        ssh ${remote_server_user}@${remote_server_address} "df -hi" | sed s'/^/        /' | tee -ai $logFile
    else
        sudo su -l ${run_sync_as} -c "${export_ssh_agent_command_with_colon} ssh ${remote_server_user}@${remote_server_address} \"df -hi\"" | sed s'/^/    /' | tee -ai $logFile
    fi

    # Wait a moment so you can easily stop this process if you made a mistake.
    sleep 5

    # Use rsync to copy / update the remote file
    echo "    Syncing disk image to remote server..." | tee -ai $logFile

    if [ "${remote_system_kind}" == "Darwin" ] ; then
        # Command if remote system is Darwin (with rsync patch)
        export rsync_command="${path_to_rsync} --rsync-path=${remote_path_to_rsync} -aNHAXEx --delete --protect-args --fileflags --force-change ${local_sparse_bundle_to_sync} ${remote_server_user}@${remote_server_address}:${remote_sparse_bundle_destination}"
    fi

    if [ "${remote_system_kind}" == "Linux" ] ; then
        # Command if remote system is Linux
        #rsync_command="${path_to_rsync} --rsync-path=${remote_path_to_rsync} -aHAEx --delete \"${local_sparse_bundle_to_sync}\" ${remote_server_user}@${remote_server_address}:${remote_sparse_bundle_destination} 2>&1 | sed s'/^/    /' | tee -ai ${logFile}"
        export rsync_command="${path_to_rsync} --rsync-path=${remote_path_to_rsync} -aHAEx --delete ${local_sparse_bundle_to_sync} ${remote_server_user}@${remote_server_address}:${remote_sparse_bundle_destination}"
        #${path_to_rsync} --rsync-path=${remote_path_to_rsync} -aHAEx --delete "${local_sparse_bundle_to_sync}" ${remote_server_user}@${remote_server_address}:${remote_sparse_bundle_destination} 2>&1 | sed s'/^/    /' | tee -ai ${logFile}
    fi

    if [ "${rsync_command}" == "" ] ; then
        echo "    WARNING! : No rsync command specified for this of remote operating system : ${remote_system_kind}"  | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi

    if [ "${run_sync_as}" == "" ] ; then
	    ${rsync_command} 2>&1 | sed s'/^/    /' | sed s'/^/    /' | tee -ai ${logFile}
	    exit ${PIPESTATUS[0]}
        rsync_return_value=$?
    else
        sudo su -l ${run_sync_as} -c "${export_ssh_agent_command_with_colon} ${rsync_command} 2>&1 | sed s'/^/    /' | sed s'/^/    /' | tee -ai ${logFile} ; exit ${PIPESTATUS[0]}"
        rsync_return_value=$?
    fi

    if [ $rsync_return_value != 0 ] ; then
        echo "    WARNING! : Occurred during disk image sync." | tee -ai $logFile
        echo "               Rsync Exit Value : $rsync_return_value" | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    else
        echo "    Remote server sparse bundle synchronized." | tee -ai $logFile
    fi

else
    if ! [ -d "${local_sparse_bundle_to_sync}" ] ; then
        # Source image is not availible or is still mounted.
        echo "    WARNING! : Source image is not available : ${local_sparse_bundle_to_sync}"  | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    else
        echo "    WARNING! : The source image is mounted : ${hdiutil_mounted_status}"  | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi
fi

exit ${SCRIPT_SUCCESS}

