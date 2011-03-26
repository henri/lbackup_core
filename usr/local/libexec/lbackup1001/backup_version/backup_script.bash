#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin

##################################################
##                                              ##
##          Lucid Information Systems           ##
##                                              ##
##              LOCAL BACKUP SCRIPT             ##
##                 (C)2001-2009                 ##
##                                              ##
##            Version 0.9.8r2-alpha5            ##
##                                              ##
##     Origionaly Developed by Henri Shustak    ##
##                                              ##
##        This software is licenced under       ##
##      the GNU GPL. This software may only     ##
##            be used or installed or           ##
##          distributed in accordance           ##
##              with this licence.              ##
##                                              ##
##           Lucid Inormatin Systems.           ##
##                                              ##
##	     The developer of this software         ##
##    maintains rights as specified in the      ##
##   Lucid Terms and Conditions availible from  ##
##            www.lucidsystems.org              ##
##                                              ##
##################################################


##
## Running this script will perform a 
## backup as specified in the configuration file
## (C)2005 Lucid Information Systems
## 
## It is important that you have a copy of Rsync
## installed which will preserve the meta data
## which you are planning to save
##
## Any patches should be submitted to 
## http://wwww.lucidsystems.org
##
## LBackup Official Home Page is
## http://www.lucidsystems.org/tools/lbackup
##


##################################
##      Structural Overview     ##
##################################                
#
#   You should only need to set
#   the primary configuration
#   for this subsystem to work.
#
#   The primary configuration
#   is perfomed in a seperate configuration
#   file. The path of this configuration file
#   should be passed in as $1
#
#   There is an exmaple configuration file
#   included called 'example_backup.conf'
#
#
#   Required Utilities : wake.py, checklog.py, growlout
#   Lucid Backup Components : maillog_script.bash
#   Dependencies : python, ssh, bash, echo, mv, rm, tee, dirname, rsync or RSyncX
#
    

## Calculate amount of changed data
## Atomic Version


##################################
##         Initial Check        ##
##################################
# Backup Using  ($1) 
# Make sure a file has been passed in on the command line
if [ $# -ne 1 ]; then
         echo 1>&2 Usage: /usr/local/sbin/lbackup configuration_file.conf
         exit -127
fi
 
 
 
########################
## Internal Functions ##
########################      

# Function is used by get_absolute_path function

# These Functions Neet to be cleanded up

# Called by the get_absolute_path funtion
function resolve_symlinks {
    # Check if it is an alias
    if [ -L "$quoted_absolute_path" ] ; then 
      #  # If Alias then find where the alias is pointing
        quoted_absolute_path=`ls -l "$quoted_absolute_path" | awk 'BEGIN { FS = " -> " } ; { print $2 }'`
        n_links_followed=$[$n_links_followed+1]
        if [ $n_links_followed -gt 99 ] ; then
            echo " ERROR! : Unable to resolve link : $quoted_path2find" | tee -ai $logFile
            echo "          The symbolic links may be causing a loop." | tee -ai $logFile
            quoted_absolute_path=-30
        fi
      resolve_symlinks
    fi
}


# Before calling this function set the varible quoted_absolute_path 
# to the best guess of the absolute path. eg: quoted_absolute_path="$0"
# Upon error : quoted_absolute_path is set to -30
# You should check for this instance a loop has occoured with the links
function get_absolute_path {
    # Find the configuration files absolute path
    
    # check for ./ at the start
    local dot_slash_test=`echo "$quoted_absolute_path" | grep '^./'`
    if [ "$dot_slash_test" != "" ]  ; then
        quoted_absolute_path=`basename $quoted_absolute_path`
    fi
    
    # find absolute path (parent path times ".." will not be striped path items)
    quoted_absolute_path=$(echo $quoted_absolute_path | grep '^/' || echo `pwd`/$quoted_absolute_path)
    
    # Reset Link Counter
    n_links_followed=0
    # Check if there are any symlinks
    resolve_symlinks
}



#
#  Mail Functions
#

# Checks the path of the mailconfigpartner has context
# If there is no context the assume a context of the backup config
function check_mailconfigpartner {
    # Check for './' and '/' at the start

    local dot_slash_test=`echo "$mailconfigpartner" | grep '^./'`
    local slash_test=`echo "$mailconfigpartner" | grep '^/'`
    if [ "$dot_slash_test" == "" ]  &&  [ "$slash_test" == "" ] ; then
        # If the mailconfigpartner has no context then assume it is in
        # the same directory as the backup_config file
        local mailconfigpartner_name=`basename $mailconfigpartner`
        mailconfigpartner="${backupConfigurationFolderPath}/${mailconfigpartner_name}"
    fi
}


# Send Mail Functions  
# Sends an email out
function send_mail_log  {
    check_mailconfigpartner
    
    ## Close Log File
    echo "" >> $logFile
    echo "" >> $logFile
    
    bash $currentdir/$mailScriptName "$mailconfigpartner"
    return 0
} 


# Backup Destionion Check
# Check that the backup destination directory is availible 
function local_backup_destination_availible  {
	# Actually we only check if there is something (not that is a directory) this allows people to
	# configure links for the backup. An error will be reported if rsync is not able to copy files
	# this is just a basic pre flight check.
	if ! [ -e "${backupDest}" ] ; then
		# It may be good to have further options such run a script to mount or make this destination availible - for another version.
		echo "ERROR! : Local backup destination is not currently available." | tee -ai $logFile
		echo "         Destination : $backupDest" | tee -ai $logFile
		echo "         Backup Cancelled." | tee -ai $logFile
		send_mail_log
		exit -1
	fi
}


# Backup Source Check
# Check that the backup source is availible 
function local_backup_source_availible  {
	# Actually we only check if there is something (not that is a directory) this allows people to
	# configure links for the backup. An error will be reported if rsync is not able to copy files
	# this is just a basic pre flight check.
	if ! [ -e "${backupSource}" ] ; then
		# It may be good to have further options such run a script to mount or make this source availible - for another version.
		echo "ERROR! : Local backup source is not currently available." | tee -ai $logFile
		echo "         Source : $backupSource" | tee -ai $logFile
		echo "         Backup Cancelled." | tee -ai $logFile
		send_mail_log
		exit -1
	fi
}


# Post Action Functions 
# Performs the post action scripts
function perform_post_action_scripts {
         
        # Perform Post Action Scripts
        if [ -s "${backup_post_action}" -a -x "${backup_post_action}" ] ; then

            echo "Checking for Post Action Scripts..."

            # Export Appropriate varibles to the scripts
            export logFile                        # post scripts have the ability to write data to the log file.
            export rsync_session_log_file         # post scripts may want to reference this file.
            export backupConfigurationFolderPath  # should have been done previously anyway.
            export backup_status                  # provides feed back regarding the status of the backup.
            export backupSource                   # provides the directory we are backing up (carful may be remote).
            export backupDest                     # provides the directory we are storing the backups (carful may be remote).
            
            # This is only required for the post action not for the pre action 
            export pre_backup_script_status       # provides access to the pre status of the pre backup script actions.

            # Export the Script Return Codes
            export SCRIPT_SUCCESS
            export SCRIPT_WARNING
            export SCRIPT_HALT

            # Execute the Post Backup Actions (passing all pararmeters passed to the script)
            "${backup_post_action}" $*

            # Store the Exit Value from the Pre Backup Script
            backup_post_action_exit_value=$?


            if [ ${backup_post_action_exit_value} != ${SCRIPT_SUCCESS} ] ; then 

                # Determin weather script errors should be reported ( this will affect backup success status )
                if [ ${backup_post_action_exit_value} == ${SCRIPT_HALT} ] ; then 
                    echo 1>&2 "ERROR! : Post Backup Action Script Failed : Backup Aborted Requested" | tee -ai $logFile
                    backup_status="FIALED"
                fi

                # Check for Warning exit codes
                if [ ${backup_post_action_exit_value} == ${SCRIPT_WARNING} ] ; then 
                    echo 1>&2 "WARNING! : Post Backup Action Resulted in Warning : Backup Continuing..." | tee -ai $logFile
                else

                    # Report Undefined Exit Value
                    echo 1>&2 "WARNING! : Undefined Post Action Exit Value : ${backup_post_action_exit_value}" | tee -ai $logFile
                    echo 1>&2 "           Backup Continuing..." | tee -ai 
                fi
            fi
        fi
        
}



##################################
##      Pre Loaded Settings     ##
##################################

# Configuration mayoveride these default settings

# Is the source for this backup located on a remote machine acessed via SSH (YES/NO) 
useSSH="NO"

# Backup Pre and Post Action Script Varible Initilisers - leave these blank
backup_pre_action_script=""
backup_post_action_script=""

# Growl Notifcation
sendGrowlNotification="NO"

# Remote Rsync Path Settings for network backup via SSH
ssh_rsync_path_remote=""
default_ssh_rsync_path_remote_darwin="/usr/bin/rsync"
custom_ssh_rsync_path_remote_darwin="/usr/local/bin/rsync"
ssh_rsync_path_remote_overidden_by_configuration="NO"

# Local Rsync Path Settings for network backup via SSH
ssh_rsync_path_local=""
default_ssh_rsync_path_local_darwin="/usr/bin/rsync"
custom_ssh_rsync_path_local_darwin="/usr/local/bin/rsync"
ssh_rsync_path_local_overidden_by_configuration="NO"

# Local Rsync Path Settings for local backup 
# (fine provided we are running Mac OS 10.4.x or greater)
rsync_path_local=""
default_rsync_path_local_darwin="/usr/bin/rsync"
custom_rsync_path_local_darwin="/usr/local/bin/rsync"
rsync_path_local_overidden_by_configuration="NO"


# Local System Check
check_local_system=""
default_local_system_check="YES"

# Remote System Check
# (NOT CURRNTLY IN USE REQUIRES FURTHER TESTING + DO YOU WANT TO HAVE ANOTHER PASSWORD PROMPT OR HOLE IN SSH WRAPPER)
check_remote_system=""
default_remote_system_check="NO"

# Use Standard Version of Rsync
ssh_permit_standard_rsync_version=""
default_ssh_permit_standard_rsync_version="NO"

# Logging of Modified Files
change_options=""
itemize_changes_to_standard_log="NO"
enable_rsync_session_log="NO"
rsync_session_log_name=""
default_rsync_session_log_name="rsync_session.log"

# Locking of Backup Session
ignore_backup_lock=""
default_ignore_backup_lock="NO"
backup_lock_file_name="backup_in_progress.lock"
backup_lock_file_absolute_path=""

# Post actions performed on backup error.
post_actions_on_backup_error=""
default_post_actions_on_backup_error="NO"

# Email Reporting lmail settings.
defautl_mailconfigpartner=""
mailconfigpartner=""
default_email_and_archive_log_on_successful_backup=""
email_and_archive_log_on_successful_backup=""

# source and destination checks
local_backup_and_source_availibility_checks_enabled=""
default_local_backup_and_source_availibility_checks_enabled="YES"


##################################
##      Load Configuration      ##
##################################

echo "Loading Backup Script Configuration Data..."

# Absolute path to configuration script (passed in $1)
quoted_absolute_path=$1; get_absolute_path
export backupConfigurationFilePath="$quoted_absolute_path"
# Absolute path to configuration folder
export backupConfigurationFolderPath=`dirname "$backupConfigurationFilePath"`

# Check file specified exists and is a lbackup command file.
if ! [ -f "$backupConfigurationFilePath" ] ; then 
    echo 1>&2 "ERROR! : Specified configuration file dose not exist" | tee -ai $logFile
    echo      "         File Referenced : $backupConfigurationFilePath" | tee -ai $logFile
    exit -127
fi

# Load configuration file parsed in to as argument $1
source "$backupConfigurationFilePath"



###########################################
##     Post Config Load Configuration    ##
###########################################


# Configure the Default Remote Rsync Path for network backups unless it has already been specified in the configuration file.
if [ "$ssh_rsync_path_remote" == "" ] ; then
	ssh_rsync_path_remote="${default_ssh_rsync_path_remote_darwin}"
else
	ssh_rsync_path_remote_overidden_by_configuration="YES"
fi

# Local source and destination availible checks (unable to modify from configuration file at present)
local_backup_and_source_availibility_checks_enabled="${default_local_backup_and_source_availibility_checks_enabled}"

# Configure the Default Local Rsync Path for network backups unless it has already been specified in the configuration file.
if [ "$ssh_rsync_path_local" == "" ] ; then
	ssh_rsync_path_local="${default_ssh_rsync_path_local_darwin}"
else
	ssh_rsync_path_local_overidden_by_configuration="YES"
	
	# If we are using SSH then the local version of rsync will need to be set to the local version of rsync specified in the config file
	if [ "${useSSH}" == "YES" ] ; then
	    custom_rsync_path_local_darwin="${ssh_rsync_path_local}"
    fi
fi

rsync_session_log_file=""
# Curenlty this is not an option in the configuration. The line below ensres this can not be set in the config file.
rsync_path_local=""
# Configure the default Local Rsync Path for local backups unless it has already been specified in the configuration file.
if [ "$rsync_path_local" == "" ] ; then
	rsync_path_local="$default_rsync_path_local_darwin"
else
	rsync_path_local_overidden_by_configuration="YES"
fi

# Currently this is not an option in the configuration. The line below ensures this can not be set in the config file.
rsync_session_log_name="${default_rsync_session_log_name}"

# Are we going to be using the standard version of rsync and then setting the appropriate flags
if [ "$ssh_permit_standard_rsync_version" == "" ] ; then
	ssh_permit_standard_rsync_version="$default_ssh_permit_standard_rsync_version"
fi

# Are we going to check the local system for a spcifc version of rsync and set appropriate options.
if [ "$check_local_system" == "" ] ; then
	check_local_system="$default_local_system_check"
fi

# Are we going to check the remote system for a spcifc version of rsync and set appropriate options.
# (NOT CURRNTLY IN USE REQUIRES FURTHER TESTING + DO YOU WANT TO HAVE ANOTHER PASSWORD PROMPT OR HOLE IN SSH WRAPPER)
if [ "$check_remote_system" == "" ] ; then
	default_remote_system_check="$default_remote_system_check"
fi

# Are we going to ignore backup locks with this configuration
if [ "$ignore_backup_lock" == "" ] ; then
	ignore_backup_lock="$default_ignore_backup_lock"
fi

# Are we going to carry on with post configurations if there is an error during the backup
if [ "$post_actions_on_backup_error}" == "" ] ; then
        default_post_actions_on_backup_error="NO"
fi

# mailconfigpartner file name
if [ "$mailconfigpartner" == "" ] ; then
        mailconfigpartner="$defautl_mailconfigpartner"
fi

# check for the reporting options regarding email.
if [ "$email_and_archive_log_on_successful_backup" == "" ] ; then
        email_and_archive_log_on_successful_backup="$email_and_archive_log_on_successful_backup"
fi

# check that the email reporting settings are valid.
if [ "$email_and_archive_log_on_successful_backup" == "YES" ] && [ "$mailconfigpartner" == "" ] ; then
        echo "WARNING! :  Error in the configuration file. Unable to follow configuration instructions." | tee -ai $logFile
        echo "            The \"email_and_archvie_log_on_sucessful_backup\" option is set to \"YES\"." | tee -ai $logFile
        echo "            However, there is no \"mailconfigpartner\" file (lmail configuration) specified" | tee -ai $logFile
        echo "            within the specified backup configuration. Backup will continue." | tee -ai $logFile
        echo "            However, no email reporting or archiving will be attempted, upon successful backup." | tee -ai $logFile
fi


#####################################
##     Additional Configuration    ##
#####################################

# Utilities
utilities_folder_name="utilities"



########################
## Internal Variables ##
########################

# Name of the Mail Script
mailScriptName="maillog_script.bash"

# Backup and Link Paths
backupDestSlash=`echo "$backupDest" | sed 's/\ /\\ /g'`
backupDestCRot=$backupDestSlash/Section.0
backupDestCRotTemp=$backupDestSlash/Section.inprogress
linkDest=$backupDestSlash/Section.0

createLinks="NO"
sshSource="$sshRemoteUser""@""$sshRemoteServer"

# Get The Backup Scripts Absolute Path
quoted_absolute_path=$0; get_absolute_path
currentfilepath="$quoted_absolute_path"
currentdir=`dirname "$currentfilepath"`

# Set The Utilities Directory Absolute Path 
utilitiesdir="$currentdir""/""$utilities_folder_name"

# Internal Configuration
log_dirPath="$backupConfigurationFolderPath"
logFile="$log_dirPath""/""$log_fileName"
EXCLUDES="$backupConfigurationFolderPath"/$excludes_filename


# Logging of modified/transfered files
if [ "${enable_rsync_session_log}" == "YES" ] ; then
	rsync_session_log_file="${log_dirPath}/${rsync_session_log_name}"
	test_for_spaces=`echo "${rsync_session_log_file}" | grep " "`
        if [ "${test_for_spaces}" != "" ] ; then
		echo "WARNING! : Unsupported configuration. The results could be unexpected."
		echo "           When creating a secondary log file, the path to this log file"
		echo "           must not contain any spaces"
	fi
fi
if [ "${itemize_changes_to_standard_log}" == "YES" ] && [ "${enable_rsync_session_log}" != "YES" ] ; then
	change_options="--itemize-changes"
fi
if [ "${enable_rsync_session_log}" == "YES" ] && [ "${itemize_changes_to_standard_log}" != "YES" ] ; then
	change_options="--log-file=${rsync_session_log_file}"
fi
if [ "${enable_rsync_session_log}" == "YES" ] && [ "${itemize_changes_to_standard_log}" == "YES" ] ; then
	echo "WARNING! : Unsupported configuration. The results may be unexpected."
	echo "           Logging changes to both the primary and secondary log files"
	echo "           simultaneously is enabled."
	change_options="--itemize-changes --log-file=${rsync_session_log_file}"
fi



# Default Pre and Post Script
default_scripts="$utilitiesdir""/""default_scripts"
backup_pre_action="$default_scripts""/""default_backup_pre_action.bash"
backup_post_action="$default_scripts""/""default_backup_post_action.bash"

# Path to Script Return Codes
script_return_codes="$default_scripts""/""script_return_codes.conf"


# Stores Status of Pre Backup Action Script
pre_backup_script_status="FAILED"

# Stores Status of Backup
backup_status="SUCCESS"

# Backup Locking (absolute path to this configurations lock file)
backup_lock_file_absolute_path="$backupConfigurationFolderPath""/""$backup_lock_file_name"



##############################
## Load Script Return Codes ##
##############################

# Check script return codes file exists.
if ! [ -f "${script_return_codes}" ] ; then
    echo 1>&2 "ERROR! : Script Return Codes can not be loaded" | tee -ai $logFile
    echo      "         File Referenced : $script_return_codes" | tee -ai $logFile
    exit -127
fi


# Load the Script Return Codes
source "${script_return_codes}"


###########################
## Varible Configuration ##
###########################
# Set up of varibles based upon what
# was set within the configuration file

# Default Script Varible Configuration
if [ "$backup_pre_action_script" != "" ] && [ -f "$backup_pre_action_script" ] ; then
    backup_pre_action="$backup_pre_action_script"
fi
if [ "$backup_post_action_script" != "" ] && [ -f "$backup_post_action_script" ] ; then
    backup_post_action="$backup_post_action_script"
fi



########################
##  Preflight Check   ##
########################

# update logfile

echo "##################" >> $logFile
echo `date` >> $logFile
echo "" >> $logFile

# Check for a backup lock and other lock related tasks if it has not been disabled
if [ "$ignore_backup_lock" == "NO" ] ; then
        
        # Check for the lock file
        if [ -f "$backup_lock_file_absolute_path" ] ; then
                # It may be good to have further options such as how long ago was the lock file generated etc (ie should the lock be ignored)
                echo "ERROR! : Backup configuration lock file detected : $backup_lock_file_absolute_path" | tee -ai $logFile
                echo "         Backup Cancelled." | tee -ai $logFile
                exit -1
        fi
        
        # Test the ability to write the lock file and report an error if there was one.
        touch "$backup_lock_file_absolute_path" 2>/dev/null
        if [ $? != 0 ] ; then
                echo "WARNING! : Unable to generate backup lock file : $backup_lock_file_absolute_path" | tee -ai $logFile  
        fi
        
        # Set a trap so that if the backup is unexpectedly exited the lock file will be removed.
        trap "{ sleep 0.5 ; rm -f \"$backup_lock_file_absolute_path\"; exit 0 ; }" EXIT

else
        # Skip backup lock file check notification not written to the log file on purpose (for this version).
        echo "Backup lock file check skipped." 
fi


# Wake Clinet
if [ "$WAKE" == "YES" ] ; then
	echo "Waking Client : $hardware_address..." | tee -ai $logFile  
	python $utilitiesdir/wake.py $hardware_address
	sleep 10
fi

# Check if The Client is up

# Ping Test - Quick Test
if [ "$PingTest" == "YES" ] ; then
    echo "Testing ICMP Connection..." | tee -ai $logFile
    pingTest=`ping -qc 5 $sshRemoteServer | grep 100%`
    if [ "$pingTest" != "" ] ; then
        echo "Server Down"  | tee -ai $logFile

        ## Close Log File
        echo "" >> $logFile
        echo "" >> $logFile
        
        # Remove the backup lock file - probably not required - this will be handled by the trap
        rm -f "$backup_lock_file_absolute_path"
        exit -1
    fi
fi



# SSH Test - If host device is operating though NAT
if ( [ "$SSHTest" == "YES" ] && [ "$useSSH" == "YES" ] ) ; then
    echo "Testing SSH Connection..." | tee -ai $logFile
    SSHTest=`ssh $sshSource "##--LBackup_SSH_Test--## ; exit 0"`
    SSHTestResult=${?}
    if ( [ "$SSHTest" != "This wrapper only supports rsync" ] && [ $SSHTestResult != 0 ] ); then
           echo "$SSHTest"  | tee -ai $logFile
           echo "SSH Test Failed" | tee -ai $logFile

           ## Close Log File
           echo "" >> $logFile
           echo "" >> $logFile
           
           # Remove the backup lock file - probably not required - this will be handled by the trap
           rm -f "$backup_lock_file_absolute_path"
           exit -1
   fi
fi 


# Check and report if the post action scripts are set to run even if there is an error.
if [ "$post_actions_on_backup_error" == "YES" ] ; then
        # Make it clear that post actions will run even if the backup has failed
        echo "Even if the backup fails, Post-Action Scripts are Enabled" | tee -ai $logFile
fi

# Check if log file email and archving is configured to occor on a sucesfful backup.
if [ "$email_and_archive_log_on_successful_backup" == "YES" ] && [ "$mailconfigpartner" != "" ] ; then
        # Make it clear that lmail (archiving and log email reporting will take place even if the backup is successful.
        echo "Even if the backup is successful, lmail (log archiving and log email reporting) will run" | tee -ai $logFile
fi



# Perform Pre Action Scripts
if [ -s "${backup_pre_action}" -a -x "${backup_pre_action}" ] ; then
    
    echo "Checking for Pre Action Scripts..."
    
    # Export Appropriate varibles to the scripts
    export logFile                        # pre scripts have the ability to write data to the log file
    export rsync_session_log_file         # pre scripts may want to use this log
    export backupConfigurationFolderPath  # should have been done previously anyway
    export backupSource                   # provides the directory we are backing up (carful may be remote)
    export backupDest                     # provides the directory we are storing the backups (carful may be remote)
    
    # Export the Script Return Codes
    export SCRIPT_SUCCESS
    export SCRIPT_WARNING
    export SCRIPT_HALT
    
    # Execute the Pre Backup Actions (passing all pararmeters passed to the script)
    "${backup_pre_action}" $*
    
    # Store the Exit Value from the Pre Backup Script
    backup_pre_action_exit_value=$?
    
    if [ ${backup_pre_action_exit_value} == ${SCRIPT_SUCCESS} ] ; then
        # Set Pre Backup Script Success Flag
        pre_backup_script_status="SUCCESS"
    else
        # Determin weather to proceed with the backup
        if [ ${backup_pre_action_exit_value} == ${SCRIPT_HALT} ] ; then 
            echo 1>&2 "ERROR! : Pre Backup Action Script Failed : Backup Aborted" | tee -ai $logFile
            
            if [ "$post_actions_on_backup_error" == "YES" ] ; then
                # We are going to run post actions even though the backup has failed
                perform_post_action_scripts
            fi
            
            send_mail_log
            
            # Remove the backup lock file - probably not required - this will be handled by the trap
            rm -f "$backup_lock_file_absolute_path"
            
            exit ${SCRIPT_HALT}
        fi
        # Check for other exit codes
        if [ ${backup_pre_action_exit_value} == ${SCRIPT_WARNING} ] ; then 
            echo 1>&2 "WARNING! : Pre Backup Action Resulted in Warning : Backup Continuing..." | tee -ai $logFile
        else
            # Report Undefined Exit Value
            echo 1>&2 "WARNING! : Undefined Pre Action Exit Value : ${backup_pre_action_exit_value}" | tee -ai $logFile
            echo 1>&2 "           Backup Continuing..." | tee -ai 
        fi
    fi    
fi




##
## Check local soruce and destination are availible ( now that we have run the pre-action scripts )
##

if [ "${local_backup_and_source_availibility_checks_enabled}" == "YES" ] ; then

    # Check local (only kind at the moment) backup directory is availible. This may need to be changed in the future.
    # For now it is a basic check. It could potentially start a sub-system to make the backup device availible.
    # This is not yet implimeted or even planned. It is just a possibility.
    local_backup_destination_availible

    # Check if the backup soruce is availible - currenlty only local. 
    # This will probably be exteded to network backups in the future.
    if [ "$useSSH" != "YES" ] ; then
    	# The source is local so check if the local source is availible
    	local_backup_source_availible
    fi
    
fi




# Report if this is the First Run
if ! [ -d "$backupDestCRot" ] ; then
	echo "First Run Full Copy..." | tee -ai $logFile
fi


if ! [ -f $EXCLUDES ] ; then
    echo "Exclude-definitions missing" | tee -ai $logFile
    
    # Remove the backup lock file - probably not required - this will be handled by the trap
    rm -f "$backup_lock_file_absolute_path"
    exit -127
fi  


# Check if Hard Links Are Required
if [ $numRotations -ge 2 ] ; then
	#Check if there are files to link to 
	if [ -d "$linkDest" ] ; then
		#make sure links are created
		createLinks="YES"
		echo "Hard Links Enabled" | tee -ai $logFile
	fi
fi


# Check whether the Last backup completed successfully
if [ -d "$backupDestCRotTemp" ] ; then
    successfully_removed_failed_backup="NO"
	echo "Previous Backup Failed" | tee -ai $logFile
  	echo "Removing Incomplete Backup...." | tee -ai $logFile
  	rm -Rf "$backupDestCRotTemp"
  	if [ $? != 0 ] ; then
        current_user=`whoami`
        if [ "${current_user}" != "root" ] ; then
            # Attempt to enable write access to the temporary files
            chmod -R +w "${backupDestCRotTemp}"
            # Try the removal again
            rm -Rf "$backupDestCRotTemp"
            if [ $? == 0 ] ; then
                successfully_removed_failed_backup="YES"
            fi 
        fi
	else
    	successfully_removed_failed_backup="YES"
    fi
    
    if [ "${successfully_removed_failed_backup}" != "YES" ] ; then
            
        backup_status="FIALED"
            
        echo "ERROR! : Removing Temporary Directory" | tee -ai $logFile
        if [ "$post_actions_on_backup_error" == "YES" ] ; then
            # We are going to run post actions even though the backup has failed
            perform_post_action_scripts
        fi
                
        send_mail_log

        # Remove the backup lock file - probably not required - this will be handled by the trap
        rm -f "$backup_lock_file_absolute_path"
        exit -1
    else
        echo "Incomplete Backup Removed" | tee -ai $logFile
    fi
fi







########################
##   RSync Options    ##
########################

# Set Show Progress
showProgress="NO"

# Checks the Remote OS if this backup is via SSH  
# (NOT CURRNTLY IN USE REQUIRES FURTHER TESTING + DO YOU WANT TO HAVE ANOTHER PASSWORD PROMPT OR HOLE IN SSH WRAPPER)
if [ "$check_remote_system" == "YES" ] && [ useSSH="YES" ] ; then
	
	echo "Testing Remote System Type and Version..." | tee -ai $logFile
    check_remote_system_results=`ssh $sshSource "uname -rs"`
    remote_system_check_TestResult=${?}
	
	if [ ${remote_system_check_TestResult} != 0 ] || [ "${check_remote_system_results}" == "" ] ; then
		echo "ERROR! : Unable to determine remote system type or version." | tee -ai $logFile
		echo "         Check the remote host is reachable and if you are using key based authentication  that" | tee -ai $logFile
		echo "         any wrapper scripts allow remote access to calls to the command : \"uname -rs\"" | tee -ai $logFile
		
		# Remove the backup lock file - probably not required - this will be handled by the trap
        rm -f "$backup_lock_file_absolute_path"
		exit -127
	else
	
		# Calculate the remote system type and version
		remote_system_type=`echo ${check_remote_system_results} | awk '{ print $1 }'`
		remote_system_version=`echo ${check_remote_system_results} | awk '{ print $2 }'`

		# Log the System Type and Version	-- before this can be enabled we need to check the error checking code.	
		#echo "    Remote System Name : ${remote_system_type}" | tee -ai $logFile
		#echo "	  Remote System Version : ${remote_system_version}" | tee -ai $logFile
		
		if [ "${remote_system_type}" == "Darwin" ] ; then
			
			accept_default_rsync_darwin_remote_ssh="NO"
			
			# Calculate the remote major dawinn version
			remote_system_major_version_darwin=`echo ${remote_system_version} | awk -F "." '{print $1}'`
			if [ $? != 0 ] ; then
				remote_darwin_version="ERROR"
			fi
				
			# Sets the minimum version of Darwin when using the remote version of the OS bundled version of rysnc ( darwin version 8 is equivilent to tiger )
			darwin_standard_rsync_minimum_version_remote=8

			# Determin wheather the standard version of rsync is acceptible for remote backup use
			# This is depeneded upon whather which major relase of Darwin is installed on the remote system.
			if [ "${remote_darwin_version}" != "ERROR" ] ; then
				if [ $remote_system_major_version_darwin -ge $darwin_standard_rsync_minimum_version_remote ] && [ "$useSSH" == "YES" ] ; then
					# Running a local backup on Mac OS X 10.4.x or greater so we accept the standard version of rsync
					# This line means we are using the default Mac OS X bundled version of rsync. This dose require
					# that we are running a good version and also not that resource forks, may take up more space.
		            accept_default_rsync_darwin_remote_ssh="YES"
				fi
			else 
				echo "ERROR! : Unable to determine major Darwin release version of the remote machine." | tee -ai $logFile
				
				# Remove the backup lock file - probably not required - this will be handled by the trap
                rm -f "$backup_lock_file_absolute_path"
				exit -127
			fi	
		fi
	fi 
fi



# Checks the Local OS
local_system_name=`uname`

if [ "$check_local_system" == "YES" ] ; then
	
	# This system has been tested on HFS+ formated partitions. It requires testing on other formats.

	# If LBackup is running on Darwin then lets set the appropriate options for a backup
    if [ "$local_system_name" == "Darwin" ] ; then
        
		# So we are running on Darwin, in which case there is probably some meta data which needs to be beacked up.

		# Check the version of Darwin which is running - ie 10.3.x / 10.4.x / 10.5.x ...etc
		local_darwin_version=`uname -r | awk -F "." '{print $1}'`
		if [ $? != 0 ] ; then
			local_darwin_version="ERROR"
		fi

		# Check if there are any custom rsync versions insalled locally
        if [ -f ${custom_rsync_path_local_darwin} ] ; then
            installed_rsync_version=`${custom_rsync_path_local_darwin} --version | head -n 1`
            
            # Gathter Some Additional Information Regarding the Current Version of Rsync
            installed_rsync_version_number=`${custom_rsync_path_local_darwin} --version | head -n 1 | awk '{print $3}'`
            installed_rsync_version_number_major=`${custom_rsync_path_local_darwin} --version | head -n 1 | awk '{print $3}' | awk -F "." '{print $1}'`
            installed_rsync_version_support_for_preserve_create_times=`${custom_rsync_path_local_darwin} --help | grep -e "--crtimes" | awk '{print $1}' | grep -e "-N" | cut -c 1-2`
            installed_rsync_version_support_for_preserve_file_flags=`${custom_rsync_path_local_darwin} --help | grep -e "--fileflags" | awk '{print $1}' | grep -e "--fileflags"`
            installed_rsync_version_support_for_affect_immutable_files=`${custom_rsync_path_local_darwin} --help | grep -e "--force-change" | awk '{print $1}' | grep -e "--force-change"`
            
            # Check if the custom local version of rsync supports mac OSX meta data
            custom_rsync_path_local_supports_mac_osx_metadata="NO"
            if [ ${installed_rsync_version_number_major} -ge 3 ] && [ "${installed_rsync_version_support_for_preserve_create_times}" == "-N" ] && [ "${installed_rsync_version_support_for_preserve_file_flags}" == "--fileflags" ] && [ "${installed_rsync_version_support_for_affect_immutable_files}" == "--force-change" ] ; then
                custom_rsync_path_local_supports_mac_osx_metadata="YES"
            fi
            
        else
        
            echo "Checking Default Rsync Version..." | tee -ai $logFile
            installed_rsync_version="STANDARD"

            # Gathter Some Additional Information Regarding the Current Version of Rsync
            installed_rsync_version_number=`${default_ssh_rsync_path_local_darwin} --version | head -n 1 | awk '{print $3}'`
            installed_rsync_version_number_major=`${default_ssh_rsync_path_local_darwin} --version | head -n 1 | awk '{print $3}' | awk -F "." '{print $1}'`
            installed_rsync_version_support_for_preserve_create_times=`${default_ssh_rsync_path_local_darwin} --help | grep -e "--crtimes" | awk '{print $1}' | grep -e "-N" | cut -c 1-2`
            installed_rsync_version_support_for_preserve_file_flags=`${default_ssh_rsync_path_local_darwin} --help | grep -e "--fileflags" | awk '{print $1}' | grep -e "--fileflags"`
            installed_rsync_version_support_for_affect_immutable_files=`${default_ssh_rsync_path_local_darwin} --help | grep -e "--force-change" | awk '{print $1}' | grep -e "--force-change"`

        fi        
        
		
		# Paramerters for selecting the standard version of rsync.
		
		# By default do we allow the default version of rsync.
		#accept_default_rsync_darwin="NO"
		accept_default_rsync_darwin="YES"
		
		if [ "$ssh_permit_standard_rsync_version" == "NO" ] && [ "$useSSH" == "YES" ]; then
			accept_default_rsync_darwin_remote_ssh="NO"
			accept_default_rsync_darwin="NO"
		fi
		
		# Determins that the minimum version of Darwin when using the local version of rysnc ( darwin version 8 is equivilent to tiger )
		darwin_standard_rsync_minimum_version_local=8
		
		# Determin wheather the standard version of rsync is acceptible for local use
		# This depends upon two factors. The first factor is to do with the version of darwin on the local system.
		# The second factor involved is wheather this is a network backup (via SSH).
		if [ "${local_darwin_version}" != "ERROR" ] ; then
			if [ $local_darwin_version -ge $darwin_standard_rsync_minimum_version_local ] ; then
				if [ "$useSSH" == "YES" ] ; then
					if [ "${accept_default_rsync_darwin_remote_ssh}" == "YES" ] ; then
						# If the remote system and this system are running Mac OS X 10.4.x or greater we accept the
						# default version of rsync  bundeed with Mac OS X to be suffecient. Using the default version
						# of rsync which is bundeled with the Mac OS X will result in the resource forks sometimes
						# requring more storage space as they are not always hard linked correctly.
						accept_default_rsync_darwin="YES"	
					fi
				else 
				    if [ "${custom_rsync_path_local_supports_mac_osx_metadata}" == "YES" ] ; then
    		            # The custom version of Rsync supports all the Mac OS X support we require. Lets us it rather than the default Mac OS X version.
                        accept_default_rsync_darwin="NO"
    		        else
    					# Running a local backup on Mac OS X 10.4.x or greater and Rsync 3 is not availible we accept the standard version of rsync
    					# This line means we are using the default Mac OS X bundled version of rsync. This dose require
    					# that we are running a good version and also not that resource forks, may take up more space.
    		            accept_default_rsync_darwin="YES"
    		        fi
                fi
			else
			    if [ "${accept_default_rsync_darwin_remote_ssh}" == "YES" ] ; then
						# If the remote system and this system are running Mac OS X 10.4.x or greater we accept the
						# default version of rsync  bundeed with Mac OS X to be suffecient. Using the default version
						# of rsync which is bundeled with the Mac OS X will result in the resource forks sometimes
						# requring more storage space as they are not always hard linked correctly.
						accept_default_rsync_darwin="YES"	
				else
                    if [ "$useSSH" == "NO" ] ; then
                        # Running a local backup on Mac OS X 10.3.9 or earlier. Therefore, we are not going to use 
                        # the default Mac OS X bundled version of rsync. 
                        accept_default_rsync_darwin="NO"
                    fi
                fi
			fi
		fi
		
		

        # Set hard link options appropriatly 
        # Code is turning into spaghetti, this needs to be re-factored.
        # ( code will requrie tidy up - check for all possibilities on all plat forms )
        # needs to be made platform independent
        
        #
        # -e, --rsh=COMMAND           specify the remote shell
        # -a, --archive               archive mode, equivalent to -rlptgoD
        # -h, --help                  show this help screen
        # -s                          is unknowen
        # -f                          is unknowen
        # 
        
        # Set Hard Link Options to null
        hardlink_option=""
        
        function rsync_version_unkown {
            echo "ERROR! : Unknown Version of Rsync Installed" | tee -ai $logFile
            echo "         Check available rsync options, before proceeding " | tee -ai $logFile
            
            # Remove the backup lock file - probably not required - this will be handled by the trap
            rm -f "$backup_lock_file_absolute_path"
            exit -127
        }
        
        
        if [ "$installed_rsync_version" == "STANDARD" ] && [ "$accept_default_rsync_darwin" == "NO" ] ; then
                    echo "ERROR! : Only standard version of rsync installed" | tee -ai $logFile
					echo "         The standard rsync version will not preserve much meta data." | tee -ai $logFile
					echo "         Upgrade your OS or install the patched version of rsync." | tee -ai $logFile
					echo "         Download patched rsync version from the URL below :" | tee -ai $logFile
					echo "         http://www.lucidsystems.org/lbackup" | tee -ai $logFile
					echo "         Backup canceled." | tee -ai $logFile
					
					# Remove the backup lock file - probably not required - this will be handled by the trap
                    rm -f "$backup_lock_file_absolute_path"
                    exit -127
        fi
        
        if [ "$accept_default_rsync_darwin" == "NO" ] ; then
        
            # set the local rsync path to the default custom version of rsync
            rsync_path_local="$custom_rsync_path_local_darwin"

            # set the ssh remote rsync path to the default if it was not overidden in the configuration
            if [ "${ssh_rsync_path_remote_overidden_by_configuration}" == "NO" ] ; then
                ssh_rsync_path_remote="$custom_ssh_rsync_path_remote_darwin"
            fi

            # set the ssh remote rsync path to the default if it was not overidden in the configuration
            if [ "${ssh_rsync_path_local_overidden_by_configuration}" == "NO" ] ; then
               ssh_rsync_path_local="$custom_ssh_rsync_path_local_darwin"
            fi
            
        
            # check if we are running rsync version 3 or later		
    	    # This is only checking the local version. This should be updated to work with all versions.
    	    if [ ${installed_rsync_version_number_major} -ge 3 ]; then
    	        # Set options for rsync version 3 to preserve meta data on mac OS X
    	        
                echo "Using custom rsync : v3..." | tee -ai $logFile
                
                # This small x option will mean that we do not cross file system bounderies...think abou this....
           
                if [ "${custom_rsync_path_local_supports_mac_osx_metadata}" == "YES" ] ; then
                    #hardlink_option="-NHAXEx --protect-args --fileflags --force-change"
                    hardlink_option="-NHAXE --protect-args --fileflags --force-change"
                else
                    echo "WARNING : This copy of RSYNC may not support certain Mac OS X meta-data." | tee -ai $logFile
    	            #hardlink_option="-HAXEx --protect-args --fileflags --force-change"
    	            hardlink_option="-HAXE --protect-args --fileflags --force-change"
    	        fi
    	    fi
    	

    		# If we are only accepting a patched version of rsync and the local rsync path has not been overidden,
    		# then lets set some options for meta data preseivation.
    		if [ "$accept_default_rsync_darwin" == "NO" ] && [ "${rsync_path_local_overidden_by_configuration}" == "NO" ]  && [ "${ssh_rsync_path_remote_overidden_by_configuration}" == "NO" ] && [ "${ssh_rsync_path_local_overidden_by_configuration}" == "NO" ] ; then
            	      
    	  		# Check for RsyncX or rsync (with fixed chown)
    	        if [ "$installed_rsync_version" == "rsync  version 2.6.0  protocol version 27" ] ; then
        
    	            # Check that the corrisponding os x package is installed
    	            rsync_search="RsyncX_v2.1.pkg"
    	            osx_package_check=`ls /Library/Receipts | grep -x "$rsync_search"`
            
    	            if [ "$osx_package_check" == "$rsync_search" ] ; then
                        echo "Using custom rsync : RsyncX..." | tee -ai $logFile
                        
    	                # We are deling with an older version of rsync (possibly RsyncX 2.1), this will require additional flags 
    	                hardlink_option="--eahfs"
    	            else
    	                # Unrcognised Version of Rsync
    	                rsync_version_unkown
    	            fi
            
    	        fi
        
            	# Check for chown Fixed Version of Rsync
    	        if [ "$installed_rsync_version" == "rsync  version 2.6.3  protocol version 28" ] ; then
    	            
    	            # Check that the corrisponding os x package is installed
    	            rsync_search="rsync.pkg"
    	            osx_package_check=`ls /Library/Receipts | grep -x "$rsync_search"`
        
    	            if [ "$osx_package_check" == "$rsync_search" ] ; then
                        echo "Using custom rsync : v2..." | tee -ai $logFile
    	              
    	                # We are deling with a patched version of rsync which is set to preserve some meta data 
    	                #hardlink_option="--hfs-mode=appledouble"
    	                hardlink_option=""
    	                echo "WARNING : This copy of RSYNC may not support certain Mac OS X meta-data." |  tee -ai $logFile
    	            else
    	                # Unrcognised Version of Rsync
    	                rsync_version_unkown
    	            fi
    	        fi
    	    fi

		else
			# Check if we are accepting the standard version of rsync
			# The standard version of rsync on the local machine is fine and or 
			# the standard version on the remote machine is fine for an SSH Backup
			if [ "$accept_default_rsync_darwin" == "YES" ] && [ ${installed_rsync_version_number_major} -le 2 ] ; then
				# The standard version of rsync is fine therefore lets set the preserver extended attributs option
				# for use with the standard version of rsync that shipped with this version of darwin. This can be abbriviated with -E
				# note that some extended-attributes with this option will take up extra space beacuase the standard version of rsync
				# is not able to hard link the resoruce forks for some files. 
				#hardlink_option="--extended-attributes"
                echo "WARNING : This copy of RSYNC may not support certain Mac OS X meta-data."
				hardlink_option="-E"
				#hardlink_option="-NHAXEx --protect-args --fileflags --force-change"
			fi	
			
		fi
		
    fi
fi


#This output is handy for development checking

#echo custom_rsync_path_local_supports_mac_osx_metadata : $custom_rsync_path_local_supports_mac_osx_metadata
#echo installed_rsync_version_support_for_preserve_file_flags : $installed_rsync_version_support_for_preserve_file_flags
#echo installed_rsync_version_support_for_affect_immutable_files : $installed_rsync_version_support_for_affect_immutable_files
#echo installed_rsync_version_support_for_preserve_create_times : $installed_rsync_version_support_for_preserve_create_times

#echo ssh_rsync_path_remote_overidden_by_configuration : $ssh_rsync_path_remote_overidden_by_configuration
#echo accept_default_rsync_darwin : $accept_default_rsync_darwin
#echo ssh_rsync_path_remote_overidden_by_configuration : $ssh_rsync_path_remote_overidden_by_configuration
#echo rsync_path_local_overidden_by_configuration : $rsync_path_local_overidden_by_configuration
#echo version : $installed_rsync_version_number_major
#echo hardlink_optons : $hardlink_option
#echo rsync path : $rsync_path_local
#exit 0


# Note that show to go is not supported by the new version of rsync.

if [ "$showProgress" == "YES" ] ; then
    if [ "$useSSH" == "YES" ] ; then
    	#SSH options

    	#options="--protocol=28 --rsync-path=${ssh_rsync_path_remote} --stats -az ${hardlink_option} --showtogo -e ssh --modify-window=20 --delete-excluded --exclude-from=$EXCLUDES"
        options="--rsync-path=${ssh_rsync_path_remote} ${change_options} --stats -az ${hardlink_option} --showtogo --modify-window=20 --delete-excluded --exclude-from=$EXCLUDES -e ssh"
        
    else
	   #nonSSH options

        options="--rsync-path=${rsync_path_local} ${change_options} --stats -a ${hardlink_option} --showtogo --modify-window=20 --delete-excluded --exclude-from=$EXCLUDES"

    fi
else
    # Do not Show Progress
    if [ "$useSSH" == "YES" ] ; then
    	#SSH options

    	#options="--protocol=28 --rsync-path=${ssh_rsync_path_remote} --stats -az ${hardlink_option} -e ssh --modify-window=20 --delete-excluded --exclude-from=$EXCLUDES"
        options="--rsync-path=${ssh_rsync_path_remote} ${change_options} --stats -az ${hardlink_option} --modify-window=20 --delete-excluded --exclude-from=$EXCLUDES -e ssh"

    else
	   #nonSSH options

        options="--rsync-path=${rsync_path_local} ${change_options} --stats -a ${hardlink_option} --modify-window=20 --delete-excluded --exclude-from=$EXCLUDES"

    fi
fi
















########################
##   Perform Backup   ##
########################


echo "Synchronizing..." | tee -ai $logFile
sleep 7

if [ "$createLinks" == "NO" ] ; then
	# Do not Create Links
	if [ "$useSSH" == "YES" ] ; then
		#Source is accessed via SSH
		#time /usr/local/bin/rsync $options $sshSource:"$backupSource" "$backupDestCRotTemp" | tee -ai $logFile
		time ${ssh_rsync_path_local} $options $sshSource:"$backupSource" "$backupDestCRotTemp" 2>&1 | tee -ai $logFile

		
	else
		#Source is locally available	
		#time /usr/local/bin/rsync $options "$backupSource" "$backupDestCRotTemp" | tee -ai $logFile
	 	time ${rsync_path_local} $options "$backupSource" "$backupDestCRotTemp" 2>&1 | tee -ai $logFile
	fi
	
else
	# Create Links
	echo "Creating Links" | tee -ai $logFile

	if [ "$useSSH" == "YES" ] ; then
		#Source is accessed via SSH
		#time /usr/local/bin/rsync $options --link-dest="$linkDest" $sshSource:"$backupSource" "$backupDestCRotTemp" | tee -ai $logFile
		time ${ssh_rsync_path_local} $options --link-dest="$linkDest" $sshSource:"$backupSource" "$backupDestCRotTemp" 2>&1 | tee -ai $logFile

	else
		#Source is locally available	
		#time /usr/local/bin/rsync $options --link-dest="$linkDest" "$backupSource" "$backupDestCRotTemp" | tee -ai $logFile
		time ${rsync_path_local} $options --link-dest="$linkDest" "$backupSource" "$backupDestCRotTemp" 2>&1 | tee -ai $logFile
	fi

	
fi




########################
##   Rotate Backups   ##
########################


# Check the log to determin weather the backup completed
# Must be a better way than this....?

backupResult=`cat $logFile | tail -n 1 | grep "speedup" | awk '{ print $5 }'`
backupResultRsyncErrorCheck=`cat $logFile | tail -n 15 | grep "rsync error"`

# Check the data trasfer was not interupted - During This Sync
if [ "$backupResult" != "speedup" ] ; then 
        
    backup_status="FIALED"
        
	echo "" | tee -ai $logFile    
	echo "WARNING! : Data Transfer Interrupted" | tee -ai $logFile
	
	if [ "$post_actions_on_backup_error" == "YES" ] ; then
        # We are going to run post actions even though the backup has failed
        perform_post_action_scripts
    fi
	
	send_mail_log

	# Remove the backup lock file - probably not required - this will be handled by the trap
    rm -f "$backup_lock_file_absolute_path"
	exit -1
fi


# Check that RSYNC did not encouter any errors - Within 15 lines of logfile
if [ "$backupResultRsyncErrorCheck" != "" ] ; then
        
    backup_status="FIALED"
        
	echo "" | tee -ai $logFile  
	echo "WARNING! : RSYNC Encountered Errors" | tee -ai $logFile
	
	if [ "$post_actions_on_backup_error" == "YES" ] ; then
        # We are going to run post actions even though the backup has failed
        perform_post_action_scripts
    fi
	
    send_mail_log
    
    # Remove the backup lock file - probably not required - this will be handled by the trap
    rm -f "$backup_lock_file_absolute_path"
    exit -1     
fi



# if there are rotations cronn the oldest one
if [ $numRotations -ge 2 ] ; then
    echo "" | tee -ai $logFile
	echo "Rotating Backups..." | tee -ai $logFile
	sleep 7
	
	# Setup Rotation Parameters
	locA=$[$numRotations-2]
	locB=$[$numRotations-1]

	# add the hard link option for the rotations


    # Remove The Oldest Rotation
    if [ -d "$backupDest/Section.$locB" ] ; then
        rm -Rf "$backupDest/Section.$locB"
        if [ $? != 0 ] ; then
            current_user=`whoami`
            if [ "${current_user}" != "root" ] ; then
                chmod -R +w "$backupDest/Section.$locB/"*
                # Try the removal again
                rm -Rf "$backupDest/Section.$locB"
            fi
        fi
    fi

	# Rotate the Current Sets
	while [ $locA -ge 0 ] ; do
		# Rotate this section
		if [ -d "$backupDest/Section.$locA" ] ; then
		      # not used for atomic backup - order is reversed
		      createLinks="YES"
		      mv -f "$backupDest/Section.$locA" "$backupDest/Section.$locB"
		fi
		locA=$[$locA-1]
		locB=$[$locB-1]
	done
fi


# Swap the finished backup into place
echo "Performing Atomic Swap..." | tee -ai $logFile

mv "$backupDestCRotTemp" "$backupDestCRot"
if [ $? != 0 ] ; then
	echo "ERROR! : Performing Atomic Swap" | tee -ai $logFile
	backup_status="FIALED"
	
    if [ "$post_actions_on_backup_error" == "YES" ] ; then
        # We are going to run post actions even though the backup has failed
        perform_post_action_scripts
    fi

    send_mail_log
    
    # Remove the backup lock file - probably not required - this will be handled by the trap
    rm -f "$backup_lock_file_absolute_path"
    exit -1
fi


# Perfrom post actions regardless of the atomic swap
perform_post_action_scripts


# Report if the Backup was Sccessfull.
if [ "${backup_status}" == "SUCCESS" ] ; then 
	echo "Backup Completed Successfully" | tee -ai $logFile
fi




## Close Log File
echo "" >> $logFile
echo "" >> $logFile
echo "" >> $logFile



# If requested by the configuration, run lmail even if the backup was successful.
# This is an experimental setting which may be removed in a future release.
if [ "$email_and_archive_log_on_successful_backup" == "YES" ] && [ "$mailconfigpartner" != "" ] ; then
        send_mail_log
fi



# Report backup has run via Growl.

if [ "$sendGrowlNotification" == "YES" ] ; then

        # Set Growl Out Location 
        growl_out_location="/usr/sbin/growlout"

        echo "Sending Growl Notification..."
        
        if [ "$useSSH" == "YES" ] ; then
            ssh $sshSource "$growl_out_location"
        fi
        if [ "$useSSH" == "NO" ] ; then
			# Check growlout is installed 
			if [ -f "$growl_out_location" ] ; then
            	"/usr/sbin/growlout"
			else
				echo "   WARNING! : Growl out was not installed at : $growl_out_location"
			fi
        fi
        
fi


# Remove the backup lock file - probably not required - this will be handled by the trap
rm -f "$backup_lock_file_absolute_path"


# Sleep machine if configured in backup configuration
if [ "$SLEEP" == "YES" ] ; then
    if [ $useSSH == "YES" ] ; then
        echo "Requesting Sleep..."
        ssh $sshSource "/usr/sbin/sleepy"
    fi
    if [ $useSSH == "NO" ] ; then
        /usr/sbin/sleepy
    fi
fi


exit 0



