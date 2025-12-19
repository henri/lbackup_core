#!/bin/bash

##
## Email Mail Error Log With Attachment Template
## (C)2005 Lucid Information Systems
## Licensed Under the GNU GPL
## http://www.lucidsystems.org
##
## version history : 
##      1.0 - intitial relase
##      1.1 - updated for new versions of md5
##

##########################
##     Configuration    ##
##########################


# Email Settings
messageRecipient="lucid@lucidsystems.org"    	        # final string in command
messageSubject="Lucid Backup Report"    		# -s
messageFromAddress="lucid@lucidsystems.org"   	        # -f
messageFromName="Lucid Backup Report"		        # -n

#messageAttachmentPath" ---- path"

messageContent="$1"
backup_identity="$2"
messageFromName="$3"
messageFromAddress="$4"
messageRecipient="$5"
attachmentName="$6"
attachmentFile=`cat <&0`




#Version String
version="1.3"



##########################
## Internal Processing  ##
##########################

cdateLOCAL=`date`
cdateGMT=`date -u`
reportDate="$cdateLOCAL" 


# Select the correct MD5 system
operating_system=`uname`
if [ "${operating_system}" == "Linux" ]; then
    MD5=md5sum
else
    MD5=md5
fi

marker=`echo $reportDate | $MD5 | awk '{print $1}'`
boundary="mail-boundary-marker.""$marker"

##########################
##    Generate Email    ##
##########################

 echo "To: $messageRecipient"
 echo "Subject: $messageSubject"
 echo "From: $messageFromName <$messageFromAddress>"
 echo "Return-Path: $messageFromAddress"
 echo "User-Agent: Lucid-Reporting-$version"
 echo 'Content-Type: multipart/mixed; boundary="'$boundary'";'
 echo "MIME-Version: 1.0"
 echo "X-Priority: 1"      
 echo "X-MSMail-Priority: High"  
 echo "X-Lucid-Report: Error-Detected"
 echo ""
 echo ""
 echo "This is a mime-encoded message"
 echo ""
 echo ""
 echo "--""$boundary"
 echo "Content-Type: text/plain; charset=ISO-8859-1"
 echo "Content-Transfer-Encoding: 7bit"
 echo ""
 echo "Lucid Backup Report $reportDate"
 echo ""
 echo "$backup_identity"
 echo "Backup Reporting was successful, however errors were detected within backup log"
 echo "It is advisable that the attached log is checked and appropriate actions proceed."
 echo ""
 echo ""
 echo "$messageContent"
 echo ""
 echo "--""$boundary"
 echo 'Content-Type: text/plain; charset=charset=ISO-8859-1; name="'$attachmentName'";'
 echo "Content-Transfer-Encoding: base64"
 echo "Content-Disposition: attachment"
 echo ""
 echo "$attachmentFile"
 echo ""
 echo "--""$boundary""--"
 echo ""

exit 0
