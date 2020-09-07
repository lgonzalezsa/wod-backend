#!/bin/bash
# ggggggggggg
clear
#ASK FOR USER TYPE TESTER CHALLENGER OR STUDENT
typename="student"
while [ "$typename" = "" ]
  do 
	echo "Choose between student, challenger, or tester please"
	read typename
	if  [ "$typename" != "student" ] && [ "$typename" != "challenger" ] && [ "$typename" != "tester" ]; then
		typename=""
	fi	
  done

echo type is  $typename

#ASK FOR RANGE: Starting number and ending number separated by a space
startrange=0
endrange=0
# while [[ $endrange -eq 0 ]]
while [[ $startrange -eq 0 || $endrange -eq 0 || $startrange -gt $endrange ]]
do
	echo "Please provide range for user: starting and ggding separated by a space:"
	read startrange endrange
  done
#ASK FOR PASSWORD: 
password=""

while [ "$password" = "" ]
do
	echo "Please provide password :"
	read password
  done

echo "this script will change username password from $typename$startrange to $typename$endrange" 

for i in $(seq $startrange $endrange); do username="$typename$i"; echo $username:$password | sudo chpasswd ; done


