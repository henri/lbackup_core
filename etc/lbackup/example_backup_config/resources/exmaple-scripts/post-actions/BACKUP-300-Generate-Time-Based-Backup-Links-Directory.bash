#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


##################################################
##						                        ##
##	         Lucid Information Systems   	    ##
##						                        ##
##	           Generate Dated Links       	    ##
##      	         (C)2009         		    ##
##						                        ##
##		          Version 0.0.4              	##
##                                              ##
##           Developed by Henri Shustak         ##
##                                              ##
##        This software is licensed under 	    ##
##                  the GNU GPL.                ##
##					                            ##
##	   The developer of this software           ##
##     maintains rights as specified in the     ##
##   Lucid Terms and Conditions available from  ##
##          http://www.lucidsystems.org     	##
##                                              ##
##################################################


#
#  This script may be used to manage a directory with
#  links to backup snap shots. The titles of the links
#  are set to the date and time when the backup runs.
#
#
# This script requires lbackup version 0.9.8.r2 or later

#
#  This script is part of the LBackup project.
#  LBackup Home : http://www.lucidsystems.org/lbackup
#  Related Page : https://connect.homeunix.com/lbackup/example_scripts
#


###### Settings ######

# Name of the directory we where put the links
links_directory_name="snapshot_links_by_backup_time"

# Kind of links ("relative" is reccomended), ("absolute" is a possibilty)
link_sytle="relative"


###### Variables ######

links_directory_exists="NO"
links_to_remove="NO"

links_directory_path="${backupDest}/${links_directory_name}"


###### Functions ######


function preflight_checks {

        if  [ -d ${links_directory_path} ] ; then
                links_directory_exists="YES"
        fi

        if [ "${backup_status}" != "SUCCESS" ] ; then
                       echo "    WARNING! : No time based backup links will be generated because the backup has not succeeded." | tee -ai $logFile
                       exit ${SCRIPT_WARNING}
        fi

}


function generate_links_directory {

        mkdir "${links_directory_path}"
        if [ $? != 0 ] ; then
                echo "    ERROR! : Unable to generate links directory" | tee -ai $logFile
                exit ${SCRIPT_WARNING}
        fi

}




function update_old_links {
        for symbolic_time_based_link in "$links_directory_path"/*
        do
                if [ -L "$symbolic_time_based_link" ] ; then

                        # Calculate some information about this symbolic link
                        link_name=`basename "$symbolic_time_based_link"`
                        link_destination=`ls -l "$symbolic_time_based_link" | awk -F " -> " '{print $2}'`
                        current_section_number=`echo "$link_destination" | awk -F "Section." '{print $2}'`

                        # If this is not a link to a section then skip this symbolic link.
                        if [ "$current_section_number" != "" ]; then

                                # Perform some additional calculations on this link.
                                # new_section_number=`echo "$current_section_number + 1" | bc`
                                new_section_number=$(expr $current_section_number + 1)
                                new_link_name="Section.$new_section_number"

                                if [ "${link_sytle}" == "absolute" ] ; then
                                    new_link_destination="${backupDest}/${new_link_name}"
                                else
                                    new_link_destination="../${new_link_name}"
                                    # we are working in a relative way, so it is essential
                                    # that we switch into the appropriate directory and work relatively.
                                    cd "${links_directory_path}"
                                fi

                                # Check the new link destination exists
                                if ! [ -d "$new_link_destination" ] ; then
                                     # Old backup snapshot which has been deleted, so we delete the link.
                                     rm "$symbolic_time_based_link"
                                     if [ $? != 0 ] ; then
                                        echo "    ERROR! : Removing outdated link failed." | tee -ai $logFile
                                        exit ${SCRIPT_WARNING}
                                     fi
                                else
                                     ln -s "$new_link_destination" "${symbolic_time_based_link}.tmp"
                                     if [ $? == 0 ] ; then
                                        rm -f "${symbolic_time_based_link}"
                                        if [ $? == 0 ] ; then
                                            mv -i "${symbolic_time_based_link}.tmp"  "$symbolic_time_based_link"
                                            if [ $? != 0 ] ; then
                                                echo "    ERROR! : Moving temporary symbolic link into place." | tee -ai $logFile
                                                exit ${SCRIPT_WARNING}
                                            fi
                                        else
                                            echo "    ERROR! : Deleting old link : ${new_link_destination}" | tee -ai $logFile
                                            exit ${SCRIPT_WARNING}
                                        fi
                                     else
                                        echo "    ERROR! : Generating Time Based Backup Link" | tee -ai $logFile
                                        exit ${SCRIPT_WARNING}
                                     fi
                                fi
                        fi
                fi

        done

}

function add_link_for_this_backup {
        # Modify this line if you would like the folders displayed with a different date and time formating.
        current_date=`date "+%Y-%m-%d_@%H-%M-%S"`
        symbolic_link_name="$current_date"
        symbolic_link_absolute_path="$links_directory_path/$symbolic_link_name"
        if [ "${link_sytle}" == "absolute" ] ; then
            ln -s "${backupDest}/Section.0" "$symbolic_link_absolute_path"
        else
            cd "${links_directory_path}"
            ln -s "../Section.0" "$symbolic_link_name"
        fi

        if [ $? != 0 ] ; then
                echo "    ERROR! : Unable to generate link to the latest backup" | tee -ai $logFile
                exit ${SCRIPT_WARNING}
        fi
}




###### LOGIC ######


preflight_checks

#echo $links_directory_exists
if ! [ "${links_directory_exists}" == "YES"  ] ; then
        generate_links_directory
fi

update_old_links
add_link_for_this_backup


exit ${SCRIPT_SUCCESS}



