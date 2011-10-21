#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin

##################################################
##                                              ##
##          Lucid Information Systems           ##
##                                              ##
##             MAIL LOGFILE SCRIPT              ##
##                    (C)2005                   ##
##                                              ##
##                 Version 0.9.8c               ##
##                                              ##
##          Developed by Henri Shustak          ##
##                                              ##
##		          Version 0.9.8e	            ##
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


##
## Running this script will archive and
## Email the log fils for the backup
## �2005 Lucid Information Systems
##



##################################
##      Structural Overview     ##
##################################
#
#   You should only neet to set
#   the Primary Configuration
#   for this subsystem to work.
#   the primary configeration
#   should be set in a seprate
#   file which sets the requred
#   enviroment varibles.
#   The path of this configuration file
#   should be passed in as $1
#
#   There is an exmaple configeration file
#   included called 'example_mail.conf'
#
#   Required Utilities : base64encode.py, checklog.py
#   Required Templates : mail_error.sh, mail_standard_attachhment.sh
#   Lucid Backup Components : backup_script.bash
#   Dependincies : python, ssh, bash, echo, mv, rm, tee, dirname, cat
#                  basename, sendmail, test
#



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
            echo " ERROR! : Unable to resolve link : $quoted_path2find"
            echo "          The symbolic links may be cuasing a loop."
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

function check_mail_configuration_exists {
        # Check file specified exists and is a lbackup command file.
	if ! [ -f "$mailConfigurationFilePath" ] ; then
                 echo 1>&2 "ERROR! : Specified configuration file dose not exist"
                 echo      "         Configeration File Referenced : $mailConfigurationFilePath"
                 exit -128
        fi
}

##################################
##         Initial Check        ##
##################################
# Backup Using  ($1)
# Make sure a file has been passed in on the command line
if [ $# -ne 1 ]; then
         echo 1>&2 Usage: /usr/local/sbin/lmail configuration_file.conf
         exit -127
fi


##################################
##      Pre Loaded Settings     ##
##################################

# Configuration mayoveride these default settings

# Mail Pre and Post Action Script Varible Initilisers - leave these blank
mail_pre_action_script=""
mail_post_action_script=""


##################################
##      Load Configuration      ##
##################################

# Note : the symbolic link checking is probably redundent
#        the file should be able to be read from the
#        symbolic link, bash should auto drefernce when
#        executing, provided the link is intact.
#        this section will need a clean up.
#
#        For now the sybolic link checking code is
#        good for debuging. And will detect any
#        broken symbolic links

echo "Loading Mail Script Configuration Data..."

# Absolute path to configuration script (passed in $1)
quoted_absolute_path=$1; get_absolute_path
export mailConfigurationFilePath=$quoted_absolute_path
# Absolute path to configuration folder
export mailConfigurationFolderPath=`dirname "$mailConfigurationFilePath"`

# check file exists after following symbolic links
# note this is currently the only place this function is called from
check_mail_configuration_exists


# Check mail file configuration file is an absolute or relaive path
# if not then set it to be in the same folder as the backup configuration

# Load configuration file parsed in to as argument $1
echo mail config file path : $mailConfigurationFilePath
source "$mailConfigurationFilePath"


#####################################
##     Additional Configuration    ##
#####################################

# Attachment Name
attachmentName="log_file.txt"

# Templates Path
template_folder_name="message_templates"

# Utilities
utilities_folder_name="utilities"

# Email Settings
messageSubject="Lucid Backup Report"   	# -s
messageFromAddress="lucid@lucidsystems.org"   # -f
messageFromName="Lucid Backup Report"	# -n

messageContent=""


########################
## Internal Variables ##
########################

# Get The Mail Scripts Absolute Path
quoted_absolute_path=$0; get_absolute_path
currentfilepath=$quoted_absolute_path
currentdir=`dirname "$currentfilepath"`

# Set The Utilities Directory Absolute Path
utilitiesdir="$currentdir""/""$utilities_folder_name"

# Internal Configuration
template_path="$currentdir""/""$template_folder_name"
logFile="$mailConfigurationFolderPath""/""$logFile_name"
logFileArchive="$mailConfigurationFolderPath""/""$logFileArchive_name"

echo logFile : $logFile
echo logFileArchive : $logFileArchive

# Sending Mail Checks
mailsent="NO"
mailsystem_specified="NO"

# Archiveng Settings
dateGMT=`date -u`
dateinfo=`date +%Y-%m-%d-%H-%M`
logFileCurrentArchive="$logFileArchive""/""$dateinfo""_$logFile_name"

# Default Pre and Post Script
default_scripts="$utilitiesdir""/""default_scripts"
mail_pre_action="$default_scripts""/""default_mail_pre_action.bash"
mail_post_action="$default_scripts""/""default_mail_post_action.bash"

# Path to Script Return Codes
script_return_codes="$default_scripts""/""script_return_codes.conf"

# Stores Status of Pre Script
pre_mail_script_status="FAILED"

# Stores Status of MailLog
maillog_status="SUCCESS"


##############################
## Load Script Return Codes ##
##############################

# Check script return codes file exists.
if ! [ -f "$script_return_codes" ] ; then
    echo 1>&2 "ERROR! : Script Return Codes can not be loaded"
    echo      "         File Referenced : $script_return_codes"
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
if [ "$mail_pre_action_script" != "" ] && [ -f "$mail_pre_action_script" ] ; then
    mail_pre_action="$mail_pre_action_script"
fi
if [ "$mail_post_action_script" != "" ] && [ -f "$mail_post_action_script" ] ; then
    mail_post_action="$mail_post_action_script"
fi


########################
##  Preflight Check   ##
########################

# Perform Pre Action Scripts
if [ -s "${mail_pre_action}" -a -x "${mail_pre_action}" ] ; then

    echo "Checking for Pre Action Scripts..."

    # Export Appropriate varibles to the scripts
    export mailConfigurationFolderPath  # should have been done previousely anyway

    # Export the Script Return Codes
    export SCRIPT_SUCCESS
    export SCRIPT_WARNING
    export SCRIPT_HALT

    # Execute the Pre Backup Actions (passing all pararmeters passed to the script)
    "${mail_pre_action}" $*

    # Store the Exit Value from the Pre Mail Script
    mail_pre_action_exit_value=$?

    if [ ${mail_pre_action_exit_value} == ${SCRIPT_SUCCESS} ] ; then
        # Set Pre Mail Script Success Flag
        pre_mail_script_status="SUCCESS"
    else
        # Determin weather to proceed with the backup
        if [ ${mail_pre_action_exit_value} == ${SCRIPT_HALT} ] ; then
            echo 1>&2 "ERROR! : Pre Mail Log Action Script Failed : Mail Log Aborted"
            send_mail_log
            exit ${SCRIPT_HALT}
        fi
        # Check for other exit codes
        if [ ${mail_pre_action_exit_value} == ${SCRIPT_WARNING} ] ; then
            echo 1>&2 "WARNING! : Pre Mail Log Action Resulted in Warning : Mail Log Continuing..."
        else
            # Report Undefined Exit Value
            echo 1>&2 "WARNING! : Undefined Pre Action Exit Value : ${mail_pre_action_exit_value}"
            echo 1>&2 "           Mail Log Continuing..."
        fi
    fi
fi




##########################
##     Read Log file    ##
##########################

if [ -f $logFile ] ; then
	#messageContent=`cat $logFile` # not used for attachments
	attachmentFile=`cat $logFile | $utilitiesdir/base64encode.py`
	if [ $? != 0 ] ; then
		newerr="Error : Reading current log file"
 		err="$err""$newerr"
	else
		echo Log File Successfully read
	fi
else
	newerr="Error : There is no current log file"
 	err="$err""$newerr"
fi



##########################
##   Archive log File   ##
##########################

# check archive folder exists
if ! [ -d $logFileArchive ] ; then
    echo "Creating Log Archive"
    mkdir $logFileArchive
    if [ $? != 0 ] ; then
        newerr="Error : Problem creating log archive folder"
	err="$err""$newerr"
    fi
fi

# Archive log file
if [ -f $logFile ] ; then
	if [ -f $logFileCurrentArchive ] ; then
		echo "Archiving Skipped : Archive with this name already exists"
		newerr="Error : Archiving Skipped : Archive with this name already exists"
		err="$err""$newerr"
	else

		mv $logFile $logFileCurrentArchive
		if [ $? != 0 ] ; then
 			newerr="Error : Unable to archive current log"
			err="$err""$newerr"
		else

		echo "Log File Archived : $logFileCurrentArchive"

		fi
	fi
fi

##########################
##   Error Detection    ##
##########################

detected_error=`cat $logFileCurrentArchive | $utilitiesdir/checklog.py -s`

##########################
##   Final Reporting    ##
##########################

# add errors to message header
messageContent=`echo $err ; echo "" ; echo "" ; echo $messageContent`

#set priority based upon Error Reporting
if [ "$err" != "" ] ; then
	echo "WARNING! : errors while generating mail"
	mail_template="$template_path""/""mail_error.sh"
else
	echo "Mail Successfully Generated"
	if [ $detected_error == 1 ] ; then
		echo "     Log file contains erors or warnings"
		echo "          Appropriate mail template : mail_logerror_attachment.sh"
		mail_template="$template_path""/""mail_logerror_attachhment.sh"
	else
		mail_template="$template_path""/""mail_standard_attachhment.sh"
	fi
fi



##########################
##      Send Email      ##
##########################

echo "mail system is : $mailsystem"
echo "Checking if Local"

if [ "$mailsystem" == "SSH" ] ; then

        mailsystem_specified="YES"

        echo "$attachmentFile" | $mail_template "$messageContent" "$backup_identity" "$attachmentName" | ssh $sshUser@$sshServer "/usr/sbin/sendmail $messageRecipient"

        if [ $? != 0 ] ; then
                mailsent="NO"
        else
                mailsent="YES"
        fi
fi

if [ "$mailsystem" == "LOCAL" ] ; then

	mailsystem_specified="YES"

	#echo "$messageRecipient" > /Volumes/External\ 30GIG/message2besent.txt
    	echo "$attachmentFile" | $mail_template "$messageContent" "$backup_identity" "$attachmentName" | /usr/sbin/sendmail $messageRecipient

	if [ $? != 0 ] ; then
                mailsent="NO"
        else
                mailsent="YES"
        fi
fi


if [ "$mailsystem_specified" == "NO"  ] ; then
    echo 'ERROR : incorrect mail system type spcified (SSH, LOCAL)' | tee -ai
fi









# Perform Post Action Scripts
if [ -s "${mail_post_action}" -a -x "${mail_post_action}" ] ; then

    echo "Checking for Post Action Scripts..."

    # Export Appropriate varibles to the scripts
    export mailConfigurationFolderPath  # should have been done previousely anyway

    # Export the Script Return Codes
    export SCRIPT_SUCCESS
    export SCRIPT_WARNING
    export SCRIPT_HALT

    # Execute the Post Mail Actions (passing all pararmeters passed to the script)
    "${mail_post_action}" $*

    # Store the Exit Value from the Pre Backup Script
    mail_post_action_exit_value=$?


    if [ ${mail_post_action_exit_value} != ${SCRIPT_SUCCESS} ] ; then

        # Determin weather script errors should be reported ( this will affect backup success status )
        if [ ${mail_post_action_exit_value} == ${SCRIPT_HALT} ] ; then
            echo 1>&2 "ERROR! : Post Mail Log Action Script Failed : MailLog Aborted Requested"
            maillog_status="FIALED"
        fi

        # Check for Warning exit codes
        if [ ${mail_post_action_exit_value} == ${SCRIPT_WARNING} ] ; then
            echo 1>&2 "WARNING! : Post Mail Log Action Resulted in Warning : Backup Continuing..."
        else
            # Report Undefined Exit Value
            echo 1>&2 "WARNING! : Undefined Post Action Exit Value : ${mail_post_action_exit_value}"
            echo 1>&2 "           Mail Log Continuing..."
        fi
    fi
fi



if [ "$mailsent" == "NO" ] ; then
    echo "ERROR! : While Sending Mail"
fi

if [ "$maillog_status" == "SUCCESS" ] ; then
    echo "Mail Spooled Successfully"
else
    echo "Mail Spooled Successfully, However Post Mail Log Actions Failed"
fi

exit 0
