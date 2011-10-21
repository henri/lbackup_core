#!/usr/bin/env bash

# (C)2011 Henri Shustak
# Lucid Information Systems
# Licensed under the GNU GPL

# This script will enable a pre and post action which will
# mount and unmount a disk image. Pass in the path to the disk image
# as the first argument.

# Version 1.2
#
# Version History
# 1.0 : Initial Release
# 1.1 : Stops the script from being exectued within the example example_backup_config
# 1.2 : Added in some basic comments to the header of this script  packages to this script

# TO DO : (1) Add a function to convert realitve paths to actual paths possibly
#         by changing directory and then using the pwd command?
#
#         (2) Additional testing of this script in various situations.
#         to determin when it breaks.

#
# This script is designed to work with the Mac OS X built in disk image framworks
# For details on creating disk images please refer to the manual page for hdiutil
# eg.  (1) open the manual page                           :  man hdiutil
#      (2) create 100MB sparsebundle image (unencrypted)  :  hdiutil create -size 100m -type SPARSEBUNDLE -fs HFS+J -volname backup_image /tmp/my_100MB_backup_image.sparsebundle
#      (3) create 100MB sparsebundle image (encrypted)    :  hdiutil create -encryption AES-256 -size 100m -type SPARSEBUNDLE -fs HFS+J -volname backup_image /tmp/my_100MB_backup_encrypted_image.sparsebundle

#
# This script is part of the LBackup project
# LBackup Home Page : http://www.lucidsystems.org/lbackup
# LBackup Related Page : https://connect.homeunix.com/lbackup/doku.php?id=network_backup_strategies
#

# input value - path to the disk image
relative_path_to_disk_image="${1}"

# internal variables

# determin the name of the backup volume
backup_volume_name=`echo "${relative_path_to_disk_image}" | grep -e "^/Volumes" | awk -F "/Volumes/" '{print $2}' | awk -F "/" '{print $1}'`
if [ "${backup_volume_name}" == "" ] ; then
    backup_volume="/"
else
    backup_volume="/Volumes/${backup_volume_name}"
fi

realitve_path_to_disk_images_initialization_script_directory=`dirname "${0}"`
relative_resources_directory="${realitve_path_to_disk_images_initialization_script_directory}/../../"

relative_pre_actions="${relative_resources_directory}pre-actions"
relative_post_actions="${relative_resources_directory}post-actions"

relative_example_pre_actions="${relative_resources_directory}exmaple-scripts/pre-actions"
relative_example_post_actions="${relative_resources_directory}exmaple-scripts/post-actions"

relative_example_src_pre_action_mount_disk_image="${relative_example_pre_actions}/BACKUP-100-BasicMountDiskImage.bash"
relative_example_src_post_action_unmount_disk_image="${relative_example_post_actions}/BACKUP-500-EjectDiskImage.bash"

relative_example_dst_pre_action_mount_disk_image="${relative_pre_actions}/BACKUP-100-BasicMountDiskImage_auto.bash"
relative_example_dst_post_action_unmount_disk_image="${relative_post_actions}/BACKUP-500-EjectDiskImage_auto.bash"

# Number of arguments passed to this script
num_arguments=$#

# preflight checks

# Check the relative_path_to_disk_image is actually an absolute path (starting with a slash)
first_char_of_relative_path_to_disk_image=`echo "${relative_path_to_disk_image}" | cut -c 1-1`
if [ "${first_char_of_relative_path_to_disk_image}" != "/" ] ; then
    echo "    ERROR! : You must specify the absolute path to the disk image."
    exit -1
fi

# Check the operating system kind and version
os_name=`uname`
if [ "${os_name}" != "Darwin" ] ; then
    echo "    ERROR! : This script only supports Mac OS X."
    exit -1
fi
major_os_release=`uname -r | awk -F "." '{print $1}'`
if [ ${major_os_release} -le 7 ] ; then
    echo "    ERROR! : This script only supports Mac OS 10.4 and higher."
    exit -1
fi

# Check that one argument was passed into the scritp
if [ ${num_arguments} != 1 ] ; then
    echo "    Usage : initialize_disk_image_pre_and_post_hooks.bash /path/to/disk/image/to_mount_and_unmount.sparsebundle"
    exit -1
fi

# Check that this is not being executed from the standard installation directory.
# This is a basic check - the realitive path really needs to be convereted to absolute
if [ "${realitve_path_to_disk_images_initialization_script_directory}" == "/usr/local/libexec/lbackup1001/utilities/initialization_scripts/darwin" ] ; then
    echo "    ERROR! : This script should be executed from within the backup"
    echo "             configuration directory, in which which you wish to add a pre"
    echo "             and post hooks to mount and unmount the specified disk image."
    echo "             Typically, the example configuration contains a symbolic link"
    echo "             to this script. You may manually create the link or copy this"
    echo "             script as required into the following directory within your"
    echo "             backup configuration directory : \"resources/initialization-scripts/disk_images/\""
    exit -1
fi

# Check that this is not being executed from the example_backup_config directory.
# This is a basic check - the realitive path really needs to be convereted to absolute
if [ "${realitve_path_to_disk_images_initialization_script_directory}" == "/private/etc/lbackup/example_backup_config/resources/initialization-scripts/disk_images" ] || [ "${realitve_path_to_disk_images_initialization_script_directory}" == "/etc/lbackup/example_backup_config/resources/initialization-scripts/disk_images" ] ; then
    echo "    ERROR! : This script should be executed from within a backup configuration "
    echo "             directory which is not the example backup configuration."
    echo "             Typically, the example configuration contains a symbolic link"
    echo "             to this script. You may manually create the link or copy this"
    echo "             script as required into the following directory within your"
    echo "             backup configuration directory : \"resources/initialization-scripts/disk_images/\""
    exit -1
fi


# Check the source example scripts are availible within the specified lbackup configuration direcoty
if ! [ -f "${relative_example_src_pre_action_mount_disk_image}" ] || ! [ -f "${relative_example_src_post_action_unmount_disk_image}" ] ; then
    echo "     ERROR! : Unable to locate one or more of the required example pre/post action scripts"
    exit -1
fi

if [ -f "${relative_example_dst_pre_action_mount_disk_image}" ] || [ -f "${relative_example_dst_post_action_unmount_disk_image}" ] ; then
    echo ""
    echo "     ERROR! : One ore more of the pre/post action scripts has already been automatically generated."
    echo ""
    echo "              Destination pre-action  : ${relative_example_dst_pre_action_mount_disk_image}"
    echo ""
    echo "              Destination post-action : ${relative_example_dst_post_action_unmount_disk_image}"
    echo ""
    exit -1
fi

# Check the disk image specified exists
if ! [ -e "${relative_path_to_disk_image}" ] ; then
    echo "    ERROR!: Unable to locate the specified disk image"
    echo "            \"${relative_path_to_disk_image}\""
	exit -1
fi


# Mount the image to find the name of the image once it is mounted.
volume_mount_name=`hdiutil attach "${relative_path_to_disk_image}" | grep /Volumes/ | awk -F "\t" '{print $3}'`
if [ $? != 0 ] ; then
	echo "    ERROR!: Unable to mount the provided disk image"
	exit -1
fi
volume_mount_name_no_pre_volume=`echo "${volume_mount_name}" | grep -e "^/Volumes" | awk -F "/Volumes/" '{print $2}'`
if [ "${volume_mount_name_no_pre_volume}" == "" ] ; then
    echo "    ERROR!: Unable to determine the name of disk image name"
	exit -1
fi

#sleep 2

# attempt unmount of the disk image - after all this is what we will be adding into the script later.
hdiutil detach "${volume_mount_name}" > /dev/null
if [ $? != 0 ] ; then
	echo "    ERROR!: Unable to un-mount the provided disk image"
	exit -1
fi


# Copy the example scripts into place
cp "${relative_example_src_pre_action_mount_disk_image}" "${relative_example_dst_pre_action_mount_disk_image}"
if [ $? != 0 ] ; then
    echo "ERROR! : Unable to copy the pre action mount disk image script."
    exit -1
fi
cp "${relative_example_src_post_action_unmount_disk_image}" "${relative_example_dst_post_action_unmount_disk_image}"
if [ $? != 0 ] ; then
    echo "ERROR! : Unable to copy the post action unmount mount disk image script."
    exit -1
fi


# ...............................................................
# Edit the newley copied scripts so that they do what is required.
# ...............................................................

# The temp file will be used to perform edits with sed - temp file is used in case anything goes horribly wrong.
tmp_file=`mktemp /tmp/lbackup_initialize_disk_image.XXXXXXXXX`

## Edit the basic mount image script

# Replace the backup volume
cat "${relative_example_dst_pre_action_mount_disk_image}" | sed 's!backupVolume=\"/Volumes/BackupDrive1\"!backupVolume=\"'${backup_volume}'"!' > "${tmp_file}"
if [ $? != 0 ] ; then
    rm -f "${tmp_file}" "${relative_example_dst_pre_action_mount_disk_image}" "${relative_example_dst_post_action_unmount_disk_image}"
    echo "     ERROR!: Unable to set the backup volume within the destination script."
    echo "             Editing the backup volume failed."
    exit -1
fi
mv "${tmp_file}" "${relative_example_dst_pre_action_mount_disk_image}"
if [ $? != 0 ] ; then
    rm "${tmp_file}" "${relative_example_dst_pre_action_mount_disk_image}" "${relative_example_dst_post_action_unmount_disk_image}"
    echo "     ERROR!: Unable to set the backup volume within the destination script."
    echo "             Moving the edited file back into final destination."
    exit -1
fi

# Replace the backup volume
cat "${relative_example_dst_pre_action_mount_disk_image}" | sed 's!imageVolumeName=\"/Volumes/backup_data_image\"!imageVolumeName=\"'${volume_mount_name}'"!' > "${tmp_file}"
if [ $? != 0 ] ; then
    rm -f "${tmp_file}" "${relative_example_dst_pre_action_mount_disk_image}" "${relative_example_dst_post_action_unmount_disk_image}"
    echo "     ERROR!: Unable to set the image volume name volume within the destination script."
    echo "             Editing the backup volume failed."
    exit -1
fi
mv "${tmp_file}" "${relative_example_dst_pre_action_mount_disk_image}"
if [ $? != 0 ] ; then
    rm -f "${tmp_file}" "${relative_example_dst_pre_action_mount_disk_image}" "${relative_example_dst_post_action_unmount_disk_image}"
    echo "     ERROR!: Unable to set the image volume name volume within the destination script."
    echo "             Moving the edited file back into final destination."
    exit -1
fi

# Replace the image location
cat "${relative_example_dst_pre_action_mount_disk_image}" | sed 's!imageVolumeLocation=\"/Volumes/BackupDrive1/backupimage.sparseimage\"!imageVolumeLocation=\"'${relative_path_to_disk_image}'"!' > "${tmp_file}"
if [ $? != 0 ] ; then
    rm -f "${tmp_file}" "${relative_example_dst_pre_action_mount_disk_image}" "${relative_example_dst_post_action_unmount_disk_image}"
    echo "     ERROR!: Unable to set the image location within the destination script."
    echo "             Editing the backup volume failed."
    exit -1
fi
mv "${tmp_file}" "${relative_example_dst_pre_action_mount_disk_image}"
if [ $? != 0 ] ; then
    rm -f "${tmp_file}" "${relative_example_dst_pre_action_mount_disk_image}" "${relative_example_dst_post_action_unmount_disk_image}"
    echo "     ERROR!: Unable to set the image location within the destination script."
    echo "             Moving the edited file back into final destination."
    exit -1
fi

## Edit the basic mount image script
# Replace the backup volume
cat "${relative_example_dst_post_action_unmount_disk_image}" | sed 's!volume_to_unmount=\"backup_mount\"!volume_to_unmount=\"'${volume_mount_name_no_pre_volume}'"!' > "${tmp_file}"
if [ $? != 0 ] ; then
    rm -f "${tmp_file}" "${relative_example_dst_pre_action_mount_disk_image}" "${relative_example_dst_post_action_unmount_disk_image}"
    echo "     ERROR!: Unable to set the backup volume within the destination script."
    echo "             Editing the backup volume failed."
    exit -1
fi
mv "${tmp_file}" "${relative_example_dst_post_action_unmount_disk_image}"
if [ $? != 0 ] ; then
    rm -f "${tmp_file}" "${relative_example_dst_pre_action_mount_disk_image}" "${relative_example_dst_post_action_unmount_disk_image}"
    echo "     ERROR!: Unable to set the backup volume within the destination script."
    echo "             Moving the edited file back into final destination."
    exit -1
fi


# Ensure permissions on these auto generated scripts is correct
chmod 775 "${relative_example_dst_pre_action_mount_disk_image}" "${relative_example_dst_post_action_unmount_disk_image}"
if [ $? != 0 ] ; then
    echo ""
    echo "    WARNING!: Unable to configure the correct permissions on the automatically"
    echo "              generated pre and post actions. You will need to set the"
    echo "              permissions manually. It is essential that the pre and"
    echo "              post action scripts are executable."
    echo ""
fi


# Clean up the tmp file
# No need - it was moved so it is not there if everything went well.

pre_action_script_basename=`basename "${relative_example_dst_pre_action_mount_disk_image}"`
post_action_script_basename=`basename "${relative_example_dst_post_action_unmount_disk_image}"`

# Explain that permissions should be enabled
echo ""
echo "------------------------------------------------------------------------------------------"
echo ""
echo "If you have not already, it is recommended that you enable permissions on your backup"
echo "destination. Details regarding permissions are available from the following URL :"
echo "http://www.lbackup.org/permissions"
echo ""
echo "Provided it is mounted, the following command should enable permissions on the destination"
echo "backup volume : sudo vsdbutil -a \"${volume_mount_name}\""
echo ""
echo "Listed below are the basic commands for mounting and un-mounting the disk image :"
# This section needs to be reviewd. Perhaps specifing the devname : eg /dev/disk5 would be bettter?
# In order to achvie this we will need to retrive this informaiton earlier within the script.
echo "Mount this disk image     : hdiutil attach \"${relative_path_to_disk_image}\""
echo "Un-mount this disk image  : hdiutil detach \"${volume_mount_name}\""
echo ""
echo "------------------------------------------------------------------------------------------"
echo ""
echo "It is recommended that you check the automatically generated pre and post action scripts"
echo "as they may require modifications to meet your requirements."
echo ""
echo "Two scripts have been configured within this lbackup configuration directory : "
echo "  - pre-action script  :  ${pre_action_script_basename}"
echo "  - post-action script :  ${post_action_script_basename}"
echo ""


#notes :
# attach options : -owners on



