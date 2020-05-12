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
#set -x
std=$1

if [ _"$1" == _"" ]; then
	echo "Syntax: procmail-action.sh <student number> <user>"
	echo "Student number is mandatory"
	exit -1
fi
shift

usermap=$1
if [ _"$1" == _"" ]; then
	echo "Syntax: procmail-action.sh <student number> <user>"
	echo "User is mandatory"
	exit -1
fi

# We need to ensure that we've got a correct number as parameter

MIN=1
MAX=81

if [ $std -le $MIN ] ||  [ $std -ge $MAX ]; then
	echo "Student number should be between $MIN and $MAX"
	#exit -1
fi

stddir="/home/student$std"
std0="/home/student0"
cd $std0

# Read workshop list on stdin
if [ -d "$stddir" ]; then
	echo "Erasing target student dir $stddir content"
	sudo rm -rf $stddir/*
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
		sudo ansible-playbook ansible_copy_folder.yml -i inventory -e "dir=NBSONDEMAND workshop=$w myrange=$std"
	done
fi

# Now change passwd
randompw=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
echo "student$std:$randompw" | sudo chpasswd
# Instead do 2 API calls here, one for passwd change, one for status change
##Update Password
curl --header "Content-Type: application/json" \
  --request PUT \
  --data '{"password":"$randompw"}' \
  "http://77.158.163.130:3002/api/student/edit/$std"

##Update customer status to active
curl --header "Content-Type: application/json" \
  --request PUT \
  --data '{"active": "true"}' \
  "http://77.158.163.130:3002/api/customer/edit/$std"
