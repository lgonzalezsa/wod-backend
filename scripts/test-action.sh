#!/bin/bash
ACTION=$1
echo "we are working on "$ACTION
if [ _"$1" = _"" ]; then
	echo "Syntax: test-action.sh <CREATE|CLEANUP|RESET>"
	echo "ACTION is mandatory"
	exit -1
fi
shift

# Check action
if [ $ACTION != "CREATE" ]  && [ $ACTION != "CLEANUP" ]  && [ $ACTION != "RESET" ]; then
	echo "Syntax: test-action.sh <CREATE|CLEANUP|RESET>"
	echo "A correct ACTION is mandatory"
	exit -1
fi
#Jupyterhub API variable depending on site
if [ _"`hostname -s`" = _"jupyterhub2" ]; then
	PORT=10025
elif [ _"`hostname -s`" = _"jupyterhub" ]; then
	PORT=10025
elif [ _"`hostname -s`" = _"jupyterhub3" ]; then
	PORT=10026
else
	echo "This machine is not a jupyterhub machine"
	exit -1
fi

(
	echo "MAIL FROM: hpedev.hackshack@hpe.com"
	echo "RCPT TO: jupyter@`hostname`"
	echo "DATA"
	echo "Subject: $ACTION 2 4" 
	echo " "
	echo "WKSHP-HPECP-API"
	echo "."
) | telnet localhost $PORT
