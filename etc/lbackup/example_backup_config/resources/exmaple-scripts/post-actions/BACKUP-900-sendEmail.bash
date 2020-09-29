#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


######################################################
##                                                  ##
##              Lucid Information Systems           ##
##                                                  ##
##       use sendEamil send to report via email     ##
##                      (C)2020                     ##
##                                                  ##
##                   Version 0.1.0                  ##
##                                                  ##
##            Developed by Henri Shustak            ##
##                                                  ##
##          This software is licensed under         ##
##                    the GNU GPL.                  ##
##                                                  ##
##            The developer of this software        ##
##        maintains rights as specified in the      ##
##     Lucid Terms and Conditions availible from    ##
##               www.lucidsystems.org               ##
##                                                  ##
######################################################



# This script will use sendEmail to report a failed or succesful backup
# It is desinged to be used with the software package sendEmail :
# http://caspian.dotconf.net/menu/Software/SendEmail/
# 
# This script could easily be modified to meet your specific needs. If 
# assistance is required, then reach out to us : http://www.lucidsystems.org
# 
# Do not add spaces etc into any paths. This script will probably break.
# Push requests accepted via email / GitHub.
#
# Note this script is designed to just spot errors in the primary backup
# If you have post / pre action scripts which you need to monitor and 
# need to recive reports / error you would be best to look at using a
# different approach.
#
# There are various settings for sendEmail - see the website / man / help page
# for details. Quick possible approach is listed below
# /usr/local/sbin/sendEmail -m "My message\n\n" -f sender.name@sender.domain.com -t recipient.name@recipient.domain.com -u "[LBackup] Email Post Action" -s smtp.mymailserver.com -xu smtp.username -xp smtp.password
#
# You could optionally attach the log with the email if you would like.
#
# If you want to detect issues within post / pre hook scripts you could
# specify a flag or possibly modify the LBackup inbuilt mail system to use
# your prefered notification appraoch. Also, with a script halt from another 
# script, this may never be run. Important to keep in mind.
# -----------------------------------------------------------------------------------------------------------------


## Various settings which you will want to alter before running this script.
path_to_sendEmail="/usr/local/sbin/sendEmail"
message_from_name="LBackup Email"
subject_prefix="[LBackup] Post Action Email - "
email_from="sender.name@sender.domain.com"
email_to="recipient.name@recipient.domain.com"
this_backup_name="MY BIG BACKUP"
sendEmail_server_settings="-s smtp.mymailserver.com:587 -xu smtp.username -xp smtp.password"


# Send email on success
email_on_success="YES"

# Send email on failure
email_on_failure="YES"

# Script exit code
email_exit_status="0"

# -----------------------------------------------------------------------------------------------------------------

# Check the exit status and send approriate email. 
# You may want to change this around. Just an idea of what is possible.
if [ "${backup_status}" != "SUCCESS" ] ; then
    echo "    Errors detected in within backup." | tee -ai $logFile
    if [ "${email_on_failure}" == "YES" ] ; then
        echo "    Sending email to <${email_to}>." | tee -ai $logFile
        "${path_to_sendEmail}" -m "ERRORS IN ${this_backup_name} INVESTIGATE!\n\n" -f "${email_from}" -t "${email_to}" -u "${subject_prefix} : Error(s) Detected in Backup" ${sendEmail_server_settings}
        email_exit_status=$?
    fi
else
    echo "    Backup seems okay (not sure about post scripts)." | tee -ai $logFile
    if [ "${email_on_success}" == "YES" ] ; then
        echo "    Sending email to <${email_to}>." | tee -ai $logFile
        "${path_to_sendEmail}" -m "Backup ${this_backup_name} succesfull.\n\n" -f "${email_from}" -t "${email_to}" -u "${subject_prefix} : Backup Success" ${sendEmail_server_settings}
        email_exit_status=$?
    fi
fi

# exit with a warning or success depending on how sending the email went.
if [ ${email_exit_status} != 0 ] ; then
	echo "    ERROR while attempting to send email(s)!." | tee -ai $logFile
    exit ${SCRIPT_WARNING}
else
    if [ ${email_on_success} == 0 ] ; then
        echo "    Email sent succesfully." | tee -ai $logFile
    fi
    exit ${SCRIPT_SUCCESS}	
fi




