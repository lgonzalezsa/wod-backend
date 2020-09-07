#!/bin/bash
#
# Script to be called from procmail to create student setup
# Expect mapping as parameters and workshop list on standard input
#
# (c) Bruno Cornec <bruno.cornec@hpe.com>, Hewlett Packard Development
# (c) Frederic Passeron <frederic.passeron@hpe.com>, Hewlett Packard Development
#
# Released under the GPLv2 License
#
set -e
set -x

# This function returns the id number in the workshop DB when passed the workshop name
get_workshop_id() {

	id=0
	for i in `curl -s --header "Content-Type: application/json" "$APIENDPOINT/workshops" | jq -r '.[].id'`; do
		name=`curl -s --header "Content-Type: application/json" "$APIENDPOINT/workshops/$i" | jq .notebook | sed 's/"//g'`
		if [ _"$name" = _"$1" ]; then
			id=$i
			break
		fi
	done
	if [ id = 0 ]; then
		echo "Workshop ID not found remotely for $1"
		exit -1
	fi
	echo "$id"
}

# This function returns the status of the reset boolean for the workshop id given as parameter
get_reset_status() {

	ret=`curl -s --header "Content-Type: application/json" "$APIENDPOINT/workshops/$1" | jq -r '.reset'`
	echo "$ret"
}

# This function retuns the workshop name from the mail body
get_workshop_name() {
	read w
	if [ ! -n "$w" ]; then
		echo "Missing workshop name in the e-mail body"
		exit -1
	fi
	echo "$w"
}

#
# Main part
#
# Variables declaration
#

# endpoint variable - Has to be global
APIENDPOINT="https://hackshackondemand.hpedev.io/api"

# Base for student IDs is 800 for Grenoble, 0 for Mougins
if [ _"`hostname -s`" = _"jupyterhub2" ]; then
	BASESTDID=800
else
	BASESTDID=0
fi

# Main of script
action=$1
if [ _"$1" = _"" ]; then
	echo "Syntax: procmail-action.sh <CREATE|CLEANUP|RESET> <student id> <user id>"
	echo "ACTION is mandatory"
	exit -1
fi
shift

# Check action
if [ $action != "CREATE" ]  && [ $action != "CLEANUP" ]  && [ $action != "RESET" ]; then
	echo "Syntax: procmail-action.sh <CREATE|CLEANUP|RESET> <student id> <user id>"
	echo "A correct ACTION is mandatory"
	exit -1
fi

# Handle CREATE and CLEANUP first
if [ $action != "RESET" ]; then
	stdid=$1
	if [ _"$1" = _"" ]; then
		echo "Syntax: procmail-action.sh <CREATE|CLEANUP> <student id> <user id>"
		echo "Student id is mandatory"
		exit -1
	fi
	shift

	userid=$1
	if [ _"$1" = _"" ]; then
		echo "Syntax: procmail-action.sh <CREATE|CLEANUP> <student id> <user id>"
		echo "User id is mandatory"
		exit -1
	fi

	# We need to ensure that we've got a correct id as parameter if needed
	MIN=$((1+$BASESTDID))
	MAX=$((900+$BASESTDID))

	if [ $stdid -le $MIN ] ||  [ $stdid -ge $MAX ]; then
		echo "Student id ($stdid) should be between $MIN and $MAX"
		exit -1
	fi

	stddir="/home/student$stdid"
	std0="/home/student0"
	cd $std0

	# Read workshop list on stdin
	if [ -d "$stddir" ]; then
		echo "Erasing target student dir $stddir content"
		sudo rm -rf $stddir/*
		if [ "$action" = "CREATE" ]; then
			while read w; 
			do
				if [ ! -n "$w" ]; then
					continue
				fi
				if [ ! -d "$std0/$w" ]; then
					echo "Skipping non-existant workshop $w"
					continue
				fi
				echo "Copying workshop $w content into target student dir $stddir"
				sudo ansible-playbook ansible_copy_folder.yml -i inventory -e "dir=  workshop=$w myrange=$stdid"
			done
		else
			w=`get_workshop_name`
		fi
		# Now change passwd
		randompw=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)

		echo "student$stdid:$randompw" | sudo chpasswd

		# Increment the student ID by Number of jupyter students in students table
		stdid=$((stdid+$BASESTDID))

		# Instead do 2 API calls here, one for passwd change, one for status change
		##Update Password
		curl --header "Content-Type: application/json" \
  			--request PUT \
  			--data '{"password":"'$randompw'"}' \
  			"$APIENDPOINT/student/$stdid"

		if [ "$action" = "CREATE" ]; then
			##Update customer status to active
			curl --header "Content-Type: application/json" \
  				--request PUT \
  				--data '{"active": "true"}' \
  				"$APIENDPOINT/customer/$userid"
		elif [ "$action" = "CLEANUP" ]; then
			#Get Worshop reset status to determine if users should be updated to inactive or not
			id=`get_workshop_id $w`
			if [ _"`get_reset_status $id`" = _"false" ]; then
				##Update customer status to inactive
				curl --header "Content-Type: application/json" \
  					--request PUT \
  					--data '{"assigned":"false"}' \
  					"$APIENDPOINT/student/$stdid"
			else
				curl --header "Content-Type: application/json" \
  					--request PUT \
  					--data '{"assigned":"true"}' \
  					"$APIENDPOINT/student/$stdid"
	 			# set customer  to inactive by default for all workshops
        			curl --header "Content-Type: application/json" \
  					--request PUT \
  					--data '{"active": "false"}' \
  					"$APIENDPOINT/customer/$userid"
			fi
		else
			echo "Unknown action $action"
		fi
	fi

elif [ "$action" = "RESET" ]; then
	w=`get_workshop_name`
	id=`get_workshop_id $w`
	if [ _"`get_reset_status $id`" = _"true" ]; then
		# Then call the reset script
		# Get Workshop backend reset status
		if [ ! -x "$HOME/reset-$w" ]; then
			echo "Unable to reset backend for workshop $w, no script available"
			exit -1
		else
        		echo "Reseting workshop $w Backend"
			$HOME/reset-$w
		fi
		# API call TBD (active or assigned ?)
		min=`echo $tdid | cut -d, -f1`
		max=`echo $tdid | cut -d, -f2`
		i=$max
		cap=$((max-min))
		while [ $i >= $min ]; do
			# API call
			##Update customer status to inactive
			curl --header "Content-Type: application/json" \
  				--request PUT \
  				--data '{"assigned":"false"}' \
  				"$APIENDPOINT/student/$i"
			((i= i-1))
		done

		# API call to Now reset capacity to original value
	        curl --header "Content-Type: application/json" \
  			--request PUT \
  			--data '{"capacity":"'$cap'"}' \
  			"$APIENDPOINT/workshops/$id"
	fi

else
	echo "Unknown action $action"
fi
