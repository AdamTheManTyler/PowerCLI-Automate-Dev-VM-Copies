# PowerCLI-Automate-Dev-VM-Copies
PowerCLI (VMware) script used to clone servers from production, place them on host with lowest memory utilization, then power each on in correct sequence..

-----Description:
The script is designed to be run as a scheduled task regularly against a licensed VMware cluster.  For this reason the scripts first task is to force power down existing running VMs created by the previous instance.  The next phase is to begin the clone operation.  There isa "Do until" loop built into the script to basically watch the vCenter tasks status until the clone operation is completed.

Once the clone operation completes, there is a process the script completes to change the networking adapter of each cloned copy to a "dev" network.  When this process is done, there is a function called prior to the power on of each VM which evaluates the cluster's available hosts based on memory utilization.  Each VM will be configured to power on via the host with the most available RAM.  The purpose was for use on VMware clusters that were not already licensed for DRS.  In which case it would be unncecessary.




-----Requirements:

--Requirement 1:
There is some manual work to get this script automated.  It's intended to be run using a Windows Scheduled Task, however the service account (user) account used to run this scheduled task must first generate a password hash file.  Repeat, this hash file must be created using the same Windows account that is running the scheduled task.  Also this Windows account will need access/permissions in vCenter.

Generate the hash file using the following PowerShell commands.

$cred=Get-Credential
$cred.Password | ConvertFrom-Securestring
$cred.Password | ConvertFrom-Securestring | Set-Content C:\scripts\vCenterPWD

--Requirement 2:
The script is designed to be run as a scheduled task regularly against a VMware cluster.  For this reason the scripts first task is to force power down existing running VMs created by the previous run.

Regards,
Adam Tyler
