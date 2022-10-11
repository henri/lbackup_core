# lbackup_core #

<h1><img src="http://www.lbackup.org/_media/golden_safe.jpg" valign="middle"/></h1>

About
--------

LBackup is an open source (GNU GPL) backup system, aimed at systems administrators who demand reliable backups.

License: [GNU General Public License v3][1]

Additional Information
---------

Further information including basic and more advanced usage is available from the following URL: 
<http://www.lbackup.org>

This [latest alpha release][2] of LBackup-Core supports the latest release versions of macOS including macOS 10.5! 
Due to some of the updates relating to SIP on macOS, if you are running Lbackup on the the latest versions of macOS, 
you are best to run the backup via ssh even if you are backing up to local media in some circumstances. Also, there are
updates to the wrapper script in this latest version of LBcakup alpha builds to add support for rsync3.2.2 which is able 
to be compiled and fully support 64bit only operating systems and ARM (M series processors) such as macOS 10.15 and beyond.

If you wish to build an OS X package installer then the following project will be of interest : 
<http://www.github.com/henri/lbackup_install_osx>

If you wish to build a .deb installer for use on debian based operating systems then the following project will be of interest : 
<http://www.github.com/henri/lbackup_install_debian>

Instructions for installing directly from source are available from the following URL : 
<http://www.lbackup.org/source>

Information relating to monitoring backups is availible from this URL : 
<http://www.lbackup.org/monitoring_multiple_backup_logs>

Information relating to monitoring of storage systems which are used for backup : 
<http://www.lbackup.org/monitoring_backup_storage>


  [1]: http://www.gnu.org/licenses/gpl.html
  [2]: http://www.lbackup.org/download/latest_alpha_release/

