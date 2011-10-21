#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


##################################################
##						                        ##
##	         Lucid Information Systems   	    ##
##						                        ##
##	    Generate Link to Backup Configuration   ##
##      	         (C)2010         		    ##
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
#  This script may be used to mainain a link from the to the backup
#  destination directory to the backup configuration directory.
#
#
# This script requires lbackup version 0.9.8.r2 or later

#
#  This script is part of the LBackup project.
#  LBackup Home : http://www.lucidsystems.org/lbackup
#  Related Page : https://connect.homeunix.com/lbackup/example_scripts
#


###### Settings ######

# Name of the links we are generating
automatic_link_to_backup_configuration_directory_name="backup_configuration.automatic_link"


###### Variables ######

link_destination_exists="NO"
link_requires_update="YES"
previous_link_exits="NO"

automatic_link_to_backup_configuration_directory="${backupDest}/${automatic_link_to_backup_configuration_directory_name}"
new_link_destination="${backupConfigurationFolderPath}"
current_link_destination=""

###### Functions ######


function preflight_checks {

    # Check the source directory exists
    if [ -d "${new_link_destination}" ] ; then

        # Check the destination exits
        if [ -d "${backupDest}" ] ; then
            link_destination_exists="YES"

            # Check to see if there is already an exiting link
            if [ -L "${automatic_link_to_backup_configuration_directory}" ] ; then
                previous_link_exits="YES"
            fi

            # If there is an exiting link then check to see if it should be updated
            if [ "${previous_link_exits}" == "YES" ] ; then
                current_link_destination=`ls -l "${automatic_link_to_backup_configuration_directory}" | awk -F " -> " '{print $2}'`
                if [ "${current_link_destination}" == "${new_link_destination}" ] ; then
                    link_requires_update="NO"
                fi
            fi

        else
            # There is no backup directory currently availible.
            # Just report the fact and carry on with any other enabled the post action scripts
            echo "    WARNING! : Unable to generate link to backup directory." | tee -ai $logFile
            echo "               Backup destination directory was not available : " | tee -ai $logFile
            echo "               ${new_link_destination}" | tee -ai $logFile
            exit ${SCRIPT_WARNING}
        fi

    else
        # There is no backup configuration directory availible.
        # Just report the fact and carry on with any other enabled the post action scripts
        echo "    WARNING! : Unable to generate link to backup configuration directory." | tee -ai $logFile
        echo "               Backup configruation directory was not available : " | tee -ai $logFile
        echo "               ${new_link_destination}" | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi


    # if you need to debug something just uncommnet the lines below :

    #    echo "Previous Link Exits  : ${previous_link_exits}"
    #    echo "Link Requires Update : ${link_requires_update}"
    #    echo "     link dest       : ${current_link_destination}"
    #    echo "     link file       : ${automatic_link_to_backup_configuration_directory}"
    #    echo "     new dest        : ${new_link_destination}"

}


function create_link {

    if ! [ -e "${automatic_link_to_backup_configuration_directory}" ] ; then
        ln -s "${new_link_destination}" "${automatic_link_to_backup_configuration_directory}"
        if [ $? != 0 ] ; then
            echo "    WARNING! : Unable to generate link to backup configuration directory." | tee -ai $logFile
            echo "               Link Path        : ${automatic_link_to_backup_configuration_directory} " | tee -ai $logFile
            echo "               Destination Path : ${new_link_destination} " | tee -ai $logFile
            exit ${SCRIPT_WARNING}
        fi
    fi

}


function delete_link {
    if [ -L "${automatic_link_to_backup_configuration_directory}" ] ; then
        rm -f "${automatic_link_to_backup_configuration_directory}"
        if [ $? != 0 ] ; then
            echo "    WARNING! : Unable to remove the previous automatic link to the backup configuration directory." | tee -ai $logFile
            echo "               The link to the backup configuration will not be updated : " | tee -ai $logFile
            echo "               ${automatic_link_to_backup_configuration_directory}" | tee -ai $logFile
            exit ${SCRIPT_WARNING}
        fi
    fi
}


###### LOGIC ######


preflight_checks

if [ "${link_requires_update}" == "YES"  ] ; then
        if [ "${previous_link_exits}" == "YES" ] ; then
            delete_link
        fi
        create_link
fi



exit ${SCRIPT_SUCCESS}



