# PowerCLI-Automate-Dev-VM-Copies
PowerCLI (VMware) script used to clone servers from production, place them on host with lowest memory utilization, then power each on in correct sequence..

-----Description:
The script is designed to be run as a scheduled task regularly against a VMware cluster.  For this reason the scripts first task is to force power down existing running VMs created by the previous instance.  The next phase is to begin the clone operation.  There is a "Do until" loop built into the script to basically watch the vCenter tasks status until the clone operation is completed, but otherwise the clone operations will occure synchronously to preserve a consistency point objective (CPO) between VMs.

Once the clone operation completes, the script changes the networking adapter of each cloned VM to a "dev" network.  When this process is done, there is a function used prior to the power on of each VM which evaluates cluster memory resources and selcts the least loaded host.  Each VM will be configured to power on via the host with the most available RAM.  The purpose was for use on VMware clusters that were not already licensed for DRS.  In which case it would be unncecessary.


-----Information:
This script was developed and tested with vCenter 6.7 and PowerCLI, versions to follow...
VMware PowerCLI 11.5.0 build 14912921
PowerShell: Version: 5.1.14409.1018

There is an included email report on success or failure included in this script which I realize isn't very well documented.  I plan to continue developing.

-----Requirements:

--Requirement 1:
There is some manual work to get this script automated.  It's intended to be run using a Windows Scheduled Task, however the service account (user) used to run this scheduled task must first generate a password hash file.  Repeat, this hash file must be created using the same Windows account that is running the scheduled task.  Also this Windows account can be used in vCenter, but will need appropriate permissions.  vCenter doesn't necessarily need to be domain joined for this to function, it just has to match the hash file you create.

Generate the hash file using the following PowerShell commands.

$cred=Get-Credential <br>
$cred.Password | ConvertFrom-Securestring <br>
$cred.Password | ConvertFrom-Securestring | Set-Content C:\scripts\vCenterPWD

In this case the "vCenterPWD" file created by the above command represents the password hash file.
within the PowerCLI-Automate-Dev-VM-Copies script, you will find the following lines which indicate which account is used to authenticate to vCenter and calling this password hash file.

$username = 'useraccount@vsphere.local'
$pwd = Get-Content vCenterPWD | ConvertTo-SecureString
$cred = New-Object System.Management.Automation.PsCredential $username, $pwd
 
LogWrite 'Connect to VIServer'
Connect-VIServer vcenter.domain.local -credential $cred




--Requirement 2:
The script is designed to be run as a scheduled task regularly against a VMware cluster.  For this reason the scripts first task is to force power down existing running VMs created by the previous run.  To narrow down the impact, this mechanism has been configured to only look at a specific cluster VM folder.  Throughout the script you will see comments starting as #Update -".  These are places where the script will need to be updated for your environment.  I'd like to spend more time makine the script run in a more generic form and placing vars toward the top.

Regards,
Adam Tyler
adam@tylerlife.us
