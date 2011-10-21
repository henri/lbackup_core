#!/bin/bash

# (C)2009 Lucid Information Systems
# Component of LBackup : http://www.lucidsystems.org/tools/lbackup
# Licence : GNU GPL
# Moves back or forward though snapshots
# Version 1.3



skip_alias_check="NO"

### start option parsing

# Using getopts meathod of opt pasrsing is not working with the source command...

# Instead of getopts we use this very basic approach.

# maybe someone is able to come up with something better?
# for parsing arguments when running via the source command

if [ $# -gt 1 ] ; then
	if [ "${1}" == "-s" ] ; then
		skip_alias_check="YES"
	else
		echo ""
		echo "    ERROR!: Unknown option : ${1}"
		echo "            Available options : "
		echo "                   -s      (skips the check for the source command being aliased)"
		echo ""
	fi
	shift
fi

### Bend of the option parsing.

direction=${1}

function change_directory {

        # Check we are aliased
        alias_result=`alias | grep -e "^alias lcd="`
		if [ "${alias_result}" == "" ] && [ "${skip_alias_check}" == "NO" ] ; then
                echo ""
                echo "In order for this tool to function correctly, it should be"
                echo "executed via the built-in \"source\" command."
                echo ""
                echo "If you are using the BASH shell, then execute the command"
                echo "below and then run this tool again using the alias \"lcd\"."
                echo ""
                echo "alias lcd=\"source /usr/local/sbin/lcd\""
                echo ""
                echo "It is recommended that the alias command above is added to"
                echo "your BASH initialization file."
                echo ""
                echo "Personal BASH initialization files : ~/.bashrc ~/.profile"
                echo ""
                echo ""
                return -127
                #exit -127
        fi

        current_section=`echo $PWD | awk -F "/Section." '{print $2}' | awk -F "/" '{print $1}'`
        if [ "${current_section}" == "" ] ; then
                echo "ERROR!: Unable to detect any backups sets within the current working directory."
                echo "        Please ensure that your current working directory is within a backup set"
                echo "        and then try to run this command again."
                return -127
                #exit -127
        fi


        if  [ "${direction}" == "back" ] || [ "${direction}" == "older" ] || [ "${direction}" == "past" ] || [ "${direction}" == "newer" ] || [ "${direction}" == "future" ] || [ "${direction}" == "forward" ] ; then

                destination_section=${current_section}
                backup_directory="`echo $PWD | awk -F "/Section." '{print $1}'`/"
                oldest_backup_section=`ls "${backup_directory}" | grep -e "^Section." | awk -F "Section." '{print$2}' | sort -n | tail -n 1`
                most_recent_backup_section=`ls "${backup_directory}" | grep -e "^Section." | awk -F "Section." '{print$2}' | sort -n | head -n 1`


                # Moving Forward in time
                if  [ "${direction}" == "future" ] || [ "${direction}" == "forward" ] || [ "${direction}" == "newer" ] ; then
                        if [ ${current_section} -gt $most_recent_backup_section ] ; then
                        # (( destination_section -- ))
                        destination_section=`echo "${destination_section}-1" | bc`
                else
                                echo "This is most recent backup available."
                                return -127
                                #exit -127
                        fi

                fi


                # Moving Back in time
                if [ "${direction}" == "back" ] || [ "${direction}" == "past" ] || [ "${direction}" == "older" ] ; then
                        if [ ${current_section} -lt $oldest_backup_section ] ; then
                                # (( destination_section ++ ))
                                destination_section=`echo "${destination_section}+1" | bc`
                        else
                                echo "This is the oldest backup available."
                                return -127
                                #exit -127
                        fi
                fi

                # Make some modifications to the current working current working directory so that we can find the destination directory, which we plan to move to.
                new_directory=`echo "$PWD" | awk '{sub(/Section.'$current_section'/,"Section.'$destination_section'")}; 1'`

                if [ -d "${new_directory}" ] ; then
                        cd "${new_directory}"
                        if [ $? != 0 ] ; then
                                echo "ERROR! : Unable to move to the destination directory?"
                                echo "         ${new_directory}"
                                return -127
                                #exit -127
                        fi
                else
                        echo "ERROR! : The destination directory is no longer available."
                        echo "         ${new_directory}"
                        return -127
                        #exit -127
                fi


        else

                echo "Usage examples : "
                echo "  Move to a more recent backup:  . /usr/local/sbin/lcd future"
                echo "  Move to an older backup:       . /usr/local/sbin/lcd past"
                return -127
                #exit -1

        fi

        return 0
        #exit 0

}

change_directory




