#!/usr/bin/env ruby
#
##################################################
##                                              ##
##           Lucid Information Systems          ##
##                                              ##
##              Backup Once Per Day             ##
##                  (C)2011                     ##
##                                              ##
##          Developed by Henri Shustak          ##
##                                              ##
##       This software is licenced under        ##
##                  the GNU GPL.                ##
##                                              ##
##       The developer of this software         ##
##    maintains rights as specified in the      ##
##   Lucid Terms and Conditions available from  ##
##            www.lucidsystems.org              ##
##                                              ##
##################################################


#
# This script is part of the LBackup project
# http://www.lbackup.org
#
#
# Version 1.1
# 
#   v1.0 : initial release
#   v1.1 : major bug fixes
#

require 'time'
require 'fileutils'

#
# Note : post-action scripts are not executed if a backup lock file is detected.
#

# configuration
#@min_number_of_seconds_since_previous_backup_initiated_before_we_will_allow_another_to_start = "86400" # 86400 seconds is one day. 604800 is one week.
@min_number_of_seconds_since_previous_backup_initiated_before_we_will_allow_another_to_start = "86399" # 86400 seconds is one day. 604800 is one week.

# pull in some of the required enviroment varibles
@SCRIPT_HALT=`echo ${SCRIPT_HALT}`
@SCRIPT_SUCCESS=`echo ${SCRIPT_SUCCESS}`
@SCRIPT_WARNING=`echo ${SCRIPT_WARNING}`
@logFile=`echo "${logFile}"`

# intenral varibles
@current_ruby_time = Time.parse(`date`) # alterantivly you could use 'Time.now'
@seconds_since_last_backup=0
@successful_backup_start_time_detected="NO"

def calculate_start_time_of_last_successful_backup (path)
      
    # Find the last time the backup was started and succesfully completed.
    # This will find the date when the last backup was successful if that ever occored.

    # Divide up the log file into backup initiation instances
    
    # IMPORTANT : Although the code handles some instances of backup configuration locks being written to the 
    #             log it is not possible to rely on the this code for accuatly calculating the lock file information.
    #             In certian cercumstances a backup may be succesful, yet this code will not locate the correct start
    #             time and will instead detect the start point (resuting in a lock file error) as the start time.
    #             any assistance with resolving these edge cases are most welcome.
    
    last_backup_successful_backup_start_time_string=""
    configuration_lock_error_message = "ERROR! : Backup configuration lock file present : "
    log = File.readlines("#{path.chomp}")
    backup_initiation_string = "##################\n" 
    backup_log_instances = []
    backup_instance = [] # temporary storgage for building backup log instances
    current_log_line = 0
    log.reverse! # we want the end result in reverse order and we want to scan backwards so this is great.
    
    # scan out the log instances from the log file
    for current_log_line in 0 ... log.size
       line = log[current_log_line]
       if (line.strip.split(/\r|\n/).length) != 0 then  # only add it if it is not an empty line (probably a better approach exists)
           backup_instance.push(line)
           if line == backup_initiation_string then
                if not log[current_log_line-3.to_i].match(/^#{configuration_lock_error_message}/) then
                    backup_instance.reverse!
                    backup_log_instances.push(backup_instance) # add it to the backup_log_instances arrary.
                    backup_instance = [] # clear out the temporary array
                end
            end
       end
    end
    
    #find the last successful backup
    backup_log_instances.each do |bi|
       last_non_blank_entry_for_bi_instance = bi[bi.size-1]
       if last_non_blank_entry_for_bi_instance.strip == "Backup Completed Successfully" then
           # this backup was successful so we will find the date that it was started
           last_backup_successful_backup_start_time_string = bi[1].strip
           last_backup_ruby_time = Time.parse(last_backup_successful_backup_start_time_string)
           @seconds_since_last_backup = @current_ruby_time.to_i - last_backup_ruby_time.to_i
           @successful_backup_start_time_detected = "YES"
           return 0
       end
    end
    
    # if we have not found a successful backup time then this return code will make that clear.
    return -1
end


if not File.readable?("#{@logFile.chomp}") then 
    system "echo \"    Backup log is unable to be opened for examination.\" | tee -ai \"${logFile}\""
    exit @SCRIPT_WARNING.to_i
end

calculate_start_time_of_last_successful_backup(@logFile)
if @successful_backup_start_time_detected == "YES" then
    if @seconds_since_last_backup.to_i >= @min_number_of_seconds_since_previous_backup_initiated_before_we_will_allow_another_to_start.to_i then
        # allow the backup to start as enough time has passed
        exit @SCRIPT_SUCCESS.to_i
    else
        # backup was started less than one day ago therfore we must report the situation and stop the backup (by sending halt exit code)
        system "echo \"\" | tee -ai \"${logFile}\""
        system "echo \"    Backup stopped because it was successfully started less than one day ago.\" | tee -ai \"${logFile}\""
        system "echo \"\" | tee -ai \"${logFile}\""
        exit @SCRIPT_HALT.to_i
    end
else
    system "echo \"    Unable to find a previous successful backup initiation time within log file.\" | tee -ai \"${logFile}\""
    exit @SCRIPT_WARNING.to_i
end



