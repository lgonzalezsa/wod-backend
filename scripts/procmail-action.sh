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

# This function returns the status of the need of LDAP setup for the workshop id given as parameter
get_ldap_status() {

	ret=`curl -s --header "Content-Type: application/json" "$APIENDPOINT/workshops/$1" | jq -r '.ldap'`
	echo "$ret"
}

# This function updates the LDAP passwd with $randompw for the student under management (using $stdid)
update_ldap_passwd() {

	rm -f /tmp/ldif.$$
	cat > /tmp/ldif.$$ << EOF
#modify user password
dn: uid=student$stdid,ou=People,dc=hpedevlab,dc=net
changetype: modify
replace: userPassword
userPassword: $randompw
EOF
	ldapmodify -D "cn=Directory Manager" -w CloudSystem$ -p 389 -h $LDAPSRV -x -f /tmp/ldif.$$ 
	rm -f /tmp/ldif.$$
}

# This function creates a variable file in which password is stored fro athe ansble playbook to handle and use to substitue $$PASSWD in notebook the LDAP passwd with $randompw
create_var_passwd() {
  
	ansible-vault encrypt_string --vault-password-file $HOME/ansible-jupyter/vault_secret $randompw --name "'PASSSTU'" > $HOME/ansible-jupyter/$PBKDIR/variables_${w}_pass.yml
}

# This function retuns the workshop name from the mail body
get_workshop_name() {

	read w
	if [ ! -n "$w" ]; then
		echo "Missing workshop name in the e-mail body"
		exit -1
	fi
	if [ ! -d "$std0/$w" ]; then
		echo "Non-existant workshop $w"
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

#Jupyterhub API variable depending on site
if [ _"`hostname -s`" = _"jupyterhub2" ]; then
        JUPYTERHUBAPI="http://jupyterhub2.hp.local:8000"
	JUPYTERHUBTOKEN="542213857571415da66bbd716485f2c8"
	# Base for student IDs is 800 for Grenoble, 0 for Mougins
	BASESTDID=800
	LDAPSRV=ldapsrv02.hp.local
	PBKDIR="sandbox"
elif [ _"`hostname -s`" = _"jupyterhub" ]; then
        JUPYTERHUBAPI="http://jupyterhub.etc.fr.comm.hpecorp.net:8000"
	JUPYTERHUBTOKEN="f75c13f965704630bdb0af023c5da72b"
	# Base for student IDs is 800 for Grenoble, 0 for Mougins
	BASESTDID=0
	LDAPSRV=ldapsrv02.hpedevlab.net
	PBKDIR="prod"
elif [ _"`hostname -s`" = _"jupyterhub3" ]; then
        JUPYTERHUBAPI="http://jupyterhub3.etc.fr.comm.hpecorp.net:8000"
	JUPYTERHUBTOKEN="70fe9e91e8004cc4b9df2ee0ff7a1c14"
	# Base for student IDs is 800 for Grenoble, 0 for Mougins
	BASESTDID=0
	LDAPSRV=ldapsrv02.hpedevlab.net
	PBKDIR="staging"
else
	echo "This machine is not a jupyterhub machine"
	exit -1
fi

# Main of script
action=$1
echo "we are working on "$action
if [ _"$1" = _"" ]; then
	echo "Syntax: procmail-action.sh <CREATE||RESET> <student id> <user id>"
	echo "ACTION is mandatory"
	exit -1
fi
shift

# Check action
if [ $action != "CREATE" ]  && [ $action != "CLEANUP" ]  && [ $action != "RESET" ]; then
	echo "Syntax: procmail-action.sh <CREATE|CLEANUP|RESET> <student id> [<user id>]"
	echo "A correct ACTION is mandatory"
	exit -1
fi

export stdid=$1
if [ _"$1" = _"" ]; then
	echo "Syntax: procmail-action.sh <CREATE|CLEANUP|RESET> <student id> [<user id>]"
	echo "Student Username id is mandatory"
	exit -1
fi
shift

# We need to ensure that we've got a correct id as parameter if needed
MIN=1
MAX=1000

if [ $stdid -le $MIN ] ||  [ $stdid -ge $MAX ]; then
	echo "Student id ($stdid) should be between $MIN and $MAX"
	exit -1
fi

stddir="/student/student$stdid"
std0="$HOME/student0"
export w=`get_workshop_name`
id=`get_workshop_id $w`

# Handle CREATE and CLEANUP first
if [ $action != "RESET" ]; then
	userid=$1
	if [ _"$1" = _"" ]; then
		echo "Syntax: procmail-action.sh <CREATE|CLEANUP> <student id> <user id>"
		echo "Customer id is mandatory"
		exit -1
	fi

	cd $std0

	# Read workshop list on stdin
	if [ -d "$stddir" ]; then
		# Now change passwd
		randompw=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
		echo "student$stdid:$randompw" | sudo chpasswd

		# Some Notebooks need an LDAP passwd update as well
		if [ _"`get_ldap_status $id`" != _"false" ]; then
			update_ldap_passwd
			create_var_passwd
		fi

		if [ "$action" = "CREATE" ]; then
			if [ _"$stddir" != _"" ]; then
				echo "Erasing target student dir $stddir content"
				rm -rf $stddir/*
			fi
			echo "Copying workshop $w content into target student dir $stddir"
			ansible-playbook $HOME/ansible-jupyter/ansible_copy_folder.yml -i $HOME/ansible-jupyter/inventory -e "DIR=  PBKDIR=$PBKDIR WORKSHOP=$w STDID=$stdid" --vault-password-file $HOME/ansible-jupyter/vault_secret
		fi

		# Increment the student ID by Number of jupyter students in students table
    		# Only for API Calls 
		dbstdid=$((stdid+$BASESTDID))

		# Instead do 2 API calls here, one for passwd change, one for status change
		##Update Password
		curl --header "Content-Type: application/json" \
  			--request PUT \
  			--data '{"password":"'$randompw'"}' \
  			"$APIENDPOINT/student/$dbstdid"

		if [ "$action" = "CREATE" ]; then
			##Update customer status to active
			curl --header "Content-Type: application/json" \
  				--request PUT \
  				--data '{"active": "true"}' \
  				"$APIENDPOINT/customer/$userid"
			##Start Student jupyterhub dedicated server
			#curl --header "Content-Type: application/json" \
			#	--header "Authorization: token $JUPYTERHUBTOKEN" \
                        #        --location \
                        #        --request POST \
			#	--data-raw '{}' \
                        #        "$JUPYTERHUBAPI/hub/api/users/student$stdid/server"

		elif [ "$action" = "CLEANUP" ]; then
			#Delete Student jupyterhub dedicated server
			curl --header "Authorization: token $JUPYTERHUBTOKEN" \
                                --location \
				--request DELETE \
                                "$JUPYTERHUBAPI/hub/api/users/student$stdid/server" 
			#Get Worshop reset status to determine if users should be updated to inactive or not
			if [ _"`get_reset_status $id`" = _"false" ]; then
				# Possible to clean dirs because no RESET so no file needed in that dir
				if [ _"$stddir" != _"" ]; then
					echo "Erasing target student dir $stddir content"
					rm -rf $stddir/*
				fi
				##Update customer status to inactive
				curl --header "Content-Type: application/json" \
  					--request PUT \
  					--data '{"assigned":"false"}' \
  					"$APIENDPOINT/student/$dbstdid"
			else
				curl --header "Content-Type: application/json" \
  					--request PUT \
  					--data '{"assigned":"true"}' \
  					"$APIENDPOINT/student/$dbstdid"
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
	if [ _"`get_reset_status $id`" = _"true" ]; then
		# Then call the reset script
		# Get Workshop backend reset status
		if [ ! -x "$HOME/scripts/reset-$w" ]; then
			echo "Unable to reset backend for workshop $w, no script available"
			exit -1
		else
        		echo "Reseting workshop $w Backend"
			$HOME/scripts/reset-$w
		fi
		if [ _"$stddir" != _"" ]; then
			echo "Erasing target student dir $stddir content"
			rm -rf $stddir/*
		fi

		# API call TBD (active or assigned ?)
		min=`echo $stdid | cut -d, -f1`
		max=`echo $stdid | cut -d, -f2`
		min=$((min+$BASESTDID))
		max=$((max+$BASESTDID))
		i=$max
		cap=$((max-min+1))

		while [ $i -ge $min ]; do
			# API call
			##Update customer status to inactive
			curl --header "Content-Type: application/json" \
  				--request PUT \
  				--data '{"assigned":"false"}' \
  				"$APIENDPOINT/student/$i"
			((i=i-1))
		done

		# API call to Now reset capacity to original value
	        curl --header "Content-Type: application/json" \
  			--request PUT \
  			--data '{"capacity":"'$cap'"}' \
  			"$APIENDPOINT/workshop/$id"
	fi

else
	echo "Unknown action $action"
fi
echo "end of procmail-action at `date` "

