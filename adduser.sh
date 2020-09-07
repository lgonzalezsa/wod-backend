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

#AdminToken="19eafa8fd2f34ed78629a9994772784b"
AdminToken="70844ab826f349ee80dbfbfa2bf5f92e"

for i in $(seq $startrange $endrange) 
do 
	username="$typename$i"  
	sudo adduser $username --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password -ingroup jupyter
	echo $username:HPEDEV2020 | sudo chpasswd 
	curl -X POST --silent -k -H "Authorization: token $AdminToken" https://192.168.10.127:8000/hub/api/users/$username | jq
	echo $username created and Jupyter user
done
