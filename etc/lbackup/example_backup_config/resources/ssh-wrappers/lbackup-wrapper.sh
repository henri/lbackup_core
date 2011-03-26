#!/bin/tcsh -f

# /etc/rsync-wrapper
# rsync-wrapper shell script.  
# Licensed Under GNU GPL
#
# Written by  :   Mike Bombich
#
# Note :
# This script is not the latest version availible.
# Although this version has been extensivly tested with LBackup.
# It is reccomended that you obtain the latest version of this script 
# along with detailed instructions regarding the configuration of 
# SSH access from the following URL : 
#       http://www.bombich.com/mactips/rsync.html
#
# This script is executed when a user from a remote machine
# successfully authenticates with a public key.  

# The privileges of that user on this server are limited to the 
# functionality of this script. This wrapper script will verify 
# that the client is sending authorized command. If the command
# is authorized, then the original, unaltered command is run,
# if not, an error is returned. 
#
# By default this access attempts are logged in /var/logs/ 
# provided the script is run as root. However, if the script
# is executed by any other user on the system then the access
# logs will be stored in /tmp and therefore will not be
# kept on the system for long. 

# If you are using this script on a production system then
# a log rotation schedule should be configured and tested.
#
# 
#
#
# v1.1 Updated by   :   Henri Shustak, Lucid Information Systems
# 				        Added LBackup compatibility
#
# v1.2 Updated by   :   Henri Shustak, Lucid Information Systems
# 				        MultiUser Support
#                       Logging via '/usr/bin/logger' command
#                       LBackup SSH test support improved
#
# v1.3 Updated by   :   Henri Shustak, Lucid Information Systems
# 				        Added an execution of /usr/bin/rsync
#
# v1.4 Updated by   :   Henri Shustak, Lucid Information Systems
# 				        Require the rsync --sender option
#
# v1.5 Updated by   :   Henri Shustak, Lucid Information Systems
# 				        Added option for /usr/local/bin/rsync_v3
#
# v1.6 Updated by   :   Henri Shustak, Lucid Information Systems
# 				        Option for detecting the --delete option 
#
# -------------------------------------------------------------------
#
#
# Requirments : LBackup version 0.9.8p or later
#
#

# Please report any security advisories to Luicd Information Systems 
# Contact details availible from : http://www.lucidsystems.org

# Settings 
set allowDelete = "false"

set current_user_id = (`id -u`)
set user_name = (`whoami`)

if ( "${current_user_id}" == "0" ) then
    set log_dir = ("/var/log/lbackup")
    if ! ( -d "${log_dir}" ) then
        mkdir -p "${log_dir}"
        chmod 700 "${log_dir}"
    endif
else
    set user_tmp_dir = ("/tmp/${current_user_id}/")
    set log_dir = ("/tmp/${current_user_id}/lbackup")
    if ! ( -d "${log_dir}" ) then 
        if ! ( -d "${user_tmp_dir}" ) then
            mkdir -p "${user_tmp_dir}"
            chmod 700 "${user_tmp_dir}"
        endif
        mkdir -p "${log_dir}"
    endif
endif


set log_file_name = ("lbackup_ssh_wrapper.out")
set log = ("${log_dir}/${log_file_name}")
set lbackup_ssh_test_command = ("##--LBackup_SSH_Test--##")


set command = ($SSH_ORIGINAL_COMMAND)
echo -n $command[1] > $log

#if ($?command) then
#
#else
#	echo "environment variable SSH_ORIGINAL_COMMAND not set"
#	exit 127
#endif

#set command = (rsync --server --sender)

# Make sure the original command is a valid LBackup command.
if (( "$command[1]" != "/usr/local/bin/rsync_v3" ) && ( "$command[1]" != "/usr/local/bin/rsync" ) && ( "$command[1]" != "/usr/bin/rsync" ) && ( "$command[1]" != "/usr/sbin/growlout" ) && ( "$command[1]" != "/usr/sbin/sleepy" ) && ( "$command[1]" != "$lbackup_ssh_test_command" )) then
    echo -n "command rejected : `cat ${log}`" | /usr/bin/logger -p 4 -t "lbackup_ssh_wapper[${current_user_id}]"
	echo "ERROR! : Command execution denied."
	echo "         This key only grants execution of LBackup commands."
	exit 127
endif

# Ensure that --server is on the command line, to enforce running
# rsync in server mode.

if (( "$command[1]" == "/usr/local/bin/rsync" ) || ( "$command[1]" == "/usr/bin/rsync" ) || ( "$command[1]" == "/usr/local/bin/rsync_v3" )) then
	
	# Check for --server
	set ok1 = false
	foreach arg ($command)
		echo "Arg Check --server :" "$arg" >> $log
		if ("$arg" == "--server") then
			set ok1 = true
		endif
	end
	
	# Check for --sender
    set ok2 = false
	foreach arg ($command)
		echo "Arg Check --sender :" "$arg" >> $log
		if ("$arg" == "--sender") then
			set ok2 = true
		endif
	end
	
	# Check for --delete
	foreach arg ($command)
		echo "Arg Check --delete :" "$arg" >> $log
		if (("$arg" == "--delete") && ("$allowDelete" == "false")) then
			echo "You may not use rsync with the delete flag on this server!" >> $log
			exit 127
		endif
	end

	
	
	# If we're OK, run the rsync server.
	if (($ok1 == "true") && ($ok2 == "true")) then
	    echo -n "Backup initiated : command recived : `cat ${log}`" | /usr/bin/logger -p 5 -t "lbackup_ssh_wapper[${current_user_id}]"
		$command
	else
	    echo -n "command rejected : `cat ${log}`" | /usr/bin/logger -p 4 -t "lbackup_ssh_wapper[${current_user_id}]"
		echo "This does not appear to be a valid rsync request"
		exit 127
	endif
endif

if ( "$command[1]" == "/usr/sbin/growlout" ) then
    echo -n "executing command : `cat ${log}`" | /usr/bin/logger -p 5 -t "lbackup_ssh_wapper[${current_user_id}]"
    $command
endif

if ( "$command[1]" == "/usr/sbin/sleepy" ) then
    echo -n "executing command : `cat ${log}`" | /usr/bin/logger -p 5 -t "lbackup_ssh_wapper[${current_user_id}]"
    $command
endif   

if ( "$command[1]" == "$lbackup_ssh_test_command" ) then
    echo -n "Recived LBackup SSH test connection : command recived : `cat ${log}`" | /usr/bin/logger -p 6 -t "lbackup_ssh_wapper[${current_user_id}]"
    exit 0
endif 




