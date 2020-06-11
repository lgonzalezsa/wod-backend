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
startramge=0
endrange=0
while [[ $startrange -eq 0 || $endrange -eq 0 || $startrange -gt $endrange ]]
  do
	echo "Please provide range for user: starting and ending separated by a space:"
	read startrange endrange
  done
echo range from $startrange to  $endrange

echo this script will delete usernames from $typename$startrange to $typename$endrange

for i in $(seq $startrange $endrange); do username="$typename$i"; userdel -r  $username ; done


