#!/bin/bash
(
	echo "MAIL FROM: hpedev.hackshack@hpe.com"
	echo "RCPT TO: jupyter@jupyterhub"
	echo "DATA"
	echo "Subject: CREATE 21 4" 
	echo " "
	echo "WKSHP-HPECP-API"
	echo "."
) | telnet localhost 10085
