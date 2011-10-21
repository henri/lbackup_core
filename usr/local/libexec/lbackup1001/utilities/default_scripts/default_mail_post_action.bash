#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin



##################################################
##						                        ##
##	         Lucid Information Systems 	     	##
##						                        ##
##	      DEFAULT MAIL POST ACTION SCRIPT		##
##      		      ©2005			            ##
##						                        ##
##		           Version 0.1    	            ##
##                                              ##
##          Developed by Henri Shustak          ##
##                                              ##
##     This software is not licenced under 	    ##
##       the GNU GPL. This software may only  	##
##             be used or installed or 		    ##
##       distributed under liecence from     	##
##           Lucid Inormatin Systems.           ##
##						                        ##
##	     The developer of this software	        ##
##    maintains rights as specified in the      ##
##   Lucid Terms and Conditions availible from  ##
##            www.lucidsystems.org     		    ##
##                                              ##
##################################################




#################################
##          SETTINGS           ##
#################################

# Directory to Run Actions from
ACTION_DIRECTORY="${backupConfigurationFolderPath}/resources/post-actions"

# Actions names must be executable and pre-fixed with the ACTION_PREFIX value
ACTION_PREFIX="MAIL"


#################################
##       EXPORT VARIBLES       ##
#################################

    # Export Appropriate varibles to the scripts
    export backupConfigurationFolderPath  # should have been done previousely anyway

    # Export the Script Return Codes
    export SCRIPT_SUCCESS
    export SCRIPT_WARNING
    export SCRIPT_HALT

    # Export Script Varibles
    export ACTION_DIRECTORY
    export ACTION_PREFIX



#################################
##      INTERNAL VARIBLES      ##
#################################

# Value Returned at the End of the Script
final_exit_value=${SCRIPT_SUCCESS}



#################################
##            LOGIC            ##
#################################

# Directory Check
if [ -d "${ACTION_DIRECTORY}" ]; then

    # Perform valid actions with valid prefix
    for action in "${ACTION_DIRECTORY}/${ACTION_PREFIX}"* ; do

        # Check Action is Executable
        if [ -s "${action}" -a -x "${action}" ]; then

            # Export this actions name
            action_name=`basename "${action}"`
            export action_name

            # Write Post Mail Action Detils to Log
            echo "Performing Post-Action : ${action_name}" | tee -ai $logFile

            # Perform Action, passing all command line arguments

            # =================================================== #
                "${action}" $*
                action_exit_value=$?
            # =================================================== #

            # Check the Action Succeded
            if [ ${action_exit_value} != ${SCRIPT_SUCCESS} ]; then

                # Check for "Halt" Exit Value
                if [ ${action_exit_value} == ${SCRIPT_HALT} ]; then
                  final_exit_value=${SCRIPT_HALT}
                  # Stop Executing Actions
                  exit ${final_exit_value}
                fi

                # Check for "Warning" Exit Value
                if [ ${action_exit_value} == ${SCRIPT_WARNING} ]; then
                    # Store Warning Value for Return (Unless a Hault Value is Found Later)
                    final_exit_value=${SCRIPT_WARNING}
                else
                    # If the exit value is not HALT, WARNING or SUCCESS, report the last odd exit value
                    final_exit_value=${action_exit_value}
                fi
            fi
        fi
    done
fi


#################################
##        RETURN VALUE         ##
#################################

exit ${final_exit_value}


