#!/bin/bash
#
# Script to be called from procmail to create student setup
# Expect mapping as parameters and workshop list on standard input
#
# (c) Bruno Cornec <bruno.cornec@hpe.com>, Hewlett Packard Development
#
# Released under the GPLv2 License
#
set -e
set -x

action=$1
if [ _"$1" == _"" ]; then
	echo "Syntax: procmail-action.sh <CREATE|CLEANUP> <student id> <user id>"
	echo "ACTION is mandatory"
	exit -1
fi
shift

# Check action
if [ $action != "CREATE" && $action != "CLEANUP" ]; then
	echo "Syntax: procmail-action.sh <CREATE|CLEANUP> <student id> <user id>"
	echo "A correct ACTION is mandatory"
	exit -1
fi

stdid=$1
if [ _"$1" == _"" ]; then
	echo "Syntax: procmail-action.sh <CREATE|CLEANUP> <student id> <user id>"
	echo "Student id is mandatory"
	exit -1
fi
shift

userid=$1
if [ _"$1" == _"" ]; then
	echo "Syntax: procmail-action.sh <CREATE|CLEANUP> <student id> <user id>"
	echo "User is mandatory"
	exit -1
fi

# We need to ensure that we've got a correct id as parameter

MIN=1
MAX=81

if [ $stdid -le $MIN ] ||  [ $stdid -ge $MAX ]; then
	echo "Student id should be between $MIN and $MAX"
	#exit -1
fi

stddir="/home/student$stdid"
std0="/home/student0"
cd $std0

# Read workshop list on stdin
if [ -d "$stddir" ]; then
	echo "Erasing target student dir $stddir content"
	sudo rm -rf $stddir/*
	if [ "$action" == "CREATE" ]; then
		while read w; 
		do
			if [ ! -n "$w" ]; then
				continue
			fi
			if [ ! -d $std0/NBSONDEMAND/$w ]; then
				echo "Skipping non-existant workshop $w"
				continue
			fi
			echo "Copying workshop $w content into target student dir $stddir"
			sudo ansible-playbook ansible_copy_folder.yml -i inventory -e "dir=NBSONDEMAND workshop=$w myrange=$stdid"
	done
	fi
fi

# Now change passwd
randompw=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
echo "student$stdid:$randompw" | sudo chpasswd
# Instead do 2 API calls here, one for passwd change, one for status change
##Update Password
curl --header "Content-Type: application/json" \
  --request PUT \
  --data '{"password":"'$randompw'"}' \
  "http://77.158.163.130:3002/api/student/edit/$stdid"

if [ "$action" == "CREATE" ]; then
	##Update customer status to active
	curl --header "Content-Type: application/json" \
  --request PUT \
  --data '{"active": "true"}' \
  "http://77.158.163.130:3002/api/customer/edit/$userid"
elif [ "$action" == "CLEANUP" ]; then
	##Update customer status to inactive
	curl --header "Content-Type: application/json" \
  --request PUT \
  --data '{"active": "false"}' \
  "http://77.158.163.130:3002/api/customer/edit/$userid"
else
	echo "Unknown action $action"
fi
