#!/bin/bash
clear
#ASK FOR USER TYPE TESTER CHALLENGER OR STUDENT
typename=""
while [ "$typename" = "" ]
  do 
	echo "Choose between student, challenger, or tester please"
	read typename
	if  [ "$typename" != "student" ] && [ "$typename" != "challenger" ] && [ "$typename" != "tester" ]; then
		echo "invalid entry $typename"
		typename=""
	fi	
  done

echo type is  $typename

#ASK FOR RANGE: Starting number and ending number separated by a space
startrange=0
endrange=0
while [[ $startrange -eq 0 || $endrange -eq 0 || $startrange -gt $endrange ]]
do
	echo "Please provide range for user: starting and ending separated by a space:"
	read startrange endrange
  done
echo range from $startrange to  $endrange

echo this script will create usernames from $typename$startrange to $typename$endrange

AdminToken="a1265a6032b544d890f8a69a4a9fd2c2"

for i in $(seq $startrange $endrange) 
do 
	username="$typename$i"  
	adduser $username --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password -ingroup jupyter
	echo $username:hpeDEV2020 | chpasswd 
	curl -X POST --silent -k -H "Authorization: token $AdminToken" https://16.31.85.200:8000/hub/api/users/$username | jq
	echo $username created and Jupyter user
done
