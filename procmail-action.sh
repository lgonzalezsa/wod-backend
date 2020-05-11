#!/bin/bash
#
# Script to be called from procmail to create student setup
#
set -e
std=$1

if [ _"$1" == _"" ]; then
	echo "Syntax: procmail-action.sh <student number> <workshop1> [<workshop1>..<workshopn>]"
	echo "Student number is mandatory"
	exit -1
fi
shift
wks="$*"
if [ _"$1" == _"" ]; then
	echo "Syntax: procmail-action.sh <student number> <workshop1> [<workshop1>..<workshopn>]"
	echo "Workshop name is mandatory"
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

if [ -d "$stddir" ]; then
	echo "Erasing target student dir $stddir content"
	sudo rm -rf $stddir/*
	for w in $*; do
		if [ ! -d $std0/NBSONDEMAND/$w ]; then
			echo "Skipping non-existant workshop $w"
			continue
		fi
		echo "Copying workshop $w content into target student dir $stddir"
		sudo ansible-playbook ansible_copy_folder.yml -e "dir=NBSONDEMAND workshop=$w myrange=$std"
	done
fi

# Now change passwd
randompw=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
echo "student$std:$randompw" | sudo chpasswd
echo "student$std $randompw" >> userpass.txt
