#! /bin/bash

##
## Email Error Template
## (C)2005 Lucid Information Systems
## Licensed Under the GNU GPL
## http://www.lucidsystems.org
##


##########################
##     Configuration    ##
##########################


# Email Settings
messageRecipient="lucid@lucidsystems.org"    	# final string in command
messageSubject="Lucid Backup Report : ERROR! "   	# -s
messageFromAddress="lucid@lucidsystems.org"   		# -f
messageFromName="Lucid Backup Report"			# -n

messageAttachmentPath=" ---- path"

messageContent="$1"
backup_identity="$2"
messageFromName="$3"
messageFromAddress="$4"
messageRecipient="$5"

#Version String
version="1.3"



##########################
## Internal Processing  ##
##########################

cdateLOCAL=`date`
cdateGMT=`date -u`
reportDate="$cdateLOCAL"

##########################
##    Generate Email    ##
##########################


echo "To: $messageRecipient"
echo "Subject: $messageSubject"
echo "From: $messageFromName <$messageFromAddress>"
echo "Return-Path: $messageFromAddress"
echo "User-Agent: Lucid-Reporting-$version"
echo "Content-Type: text/plain; charset=ISO-8859-1"
echo "Content-Transfer-Encoding: 7bit"
echo "MIME-Version: 1.0"
echo "X-Priority: 1"
echo "X-MSMail-Priority: High"
echo "X-Lucid-Report: Mail-Error"
echo ""
echo "Lucid Backup Report $reportDate"
echo ""
echo "$backup_identity"
echo "Error occurred during backup report generation."
echo "$messageContent"
echo ""


exit 0



