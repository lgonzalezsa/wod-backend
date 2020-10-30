#!/usr/local/bin/pwsh
#
# This script will install all required Powershell modules for the jupyter notebooks run

Install-Module -Name VMware.PowerCLI
Install-Module -Name HPOneView.520 -RequiredVersion 5.20.2422.3962
Install-Module -Name HPEOneView.530 -RequiredVersion 5.30.2472.1534
Install-Module -Name HPEOneView.540 -RequiredVersion 5.40.2534.2926
