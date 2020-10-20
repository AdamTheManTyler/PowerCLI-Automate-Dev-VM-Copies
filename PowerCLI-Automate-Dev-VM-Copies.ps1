<#
PowerCLI-Automate-Dev-VM-Copies written by Adam Tyler to clone production servers daily to dev environment.
Script will shut down existing VMs, clone new copies, then change networking, and finally power on.
Original script written 20200605..
#>
 
<#This is a cool if statement.  Basically checks to see if 
the PowerCLI modules are loaded, if not it will load them.  
Handy if running manually when testing from a PowerShell window.
However with the new version of PowerCLI, not absolutely necessary.
#>
 
If ( ! (Get-module VMware.VimAutomation.core )) {
 
get-module -name VMware* -ListAvailable | Import-Module
 
}

Set-Location $PSScriptRoot
push-location ./

#####################Evaluate Host memory usage function
function Eval-HostLowRAM {
	#List hosts in cluster and store in var.
	$hosts = get-vmhost
	#Out of those hosts grab MemoryUsageGb value that measures the lowest and store to var.
	$hostmem = $hosts.MemoryUsageGB | measure -Minimum
	#Because the memory value includes like 15 decimal places, trip to 1 and store in var.
	$hostmemReadable = "{0:n1}" -f $hostmem.minimum

	#begin foreach loop to match lowest memory value to host and store in var.
	foreach($h in $hosts){
	#clear vars before we begin.
	$hostmemCheck = $null
	$global:hostmemCheckReadable = $null
	$global:HostLoad = $null

	$global:hostmemCheckReadable = "{0:n1}" -f $h.MemoryUsageGB
		if($hostmemReadable -eq $hostmemCheckReadable){
		#echo "$h has lowest!  RAM: $hostmemCheckReadable"
		$global:HostLoad = $h
		}
		#if HostLoad var is populated, no reason to continue with foreach.  Issue break command to bail from foreach.
		if($HostLoad -ne $null){break}
	
	}
}

 
#####################Create log file
$datetime = (Get-Date).tostring('dd-MM-yyyy-HH-mm-ss')
$Logfile = ($datetime + '.log')
 
#####################Log write function
Function LogWrite
{
   Param ([string]$logstring)
 
   Add-content $Logfile -value $logstring
}
#####################Log write function
 
#####################Begin log
LogWrite '---------------------------->'
LogWrite 'Begin PowerCLI-Automate-Dev-VM-Copies.ps1'
$datetime = Get-Date
LogWrite ($datetime)
LogWrite '---------------------------->'

#Update - vcenter account used for operations.
$username = 'username@vsphere.local'
$pwd = Get-Content vCenterPWD | ConvertTo-SecureString
$cred = New-Object System.Management.Automation.PsCredential $username, $pwd
 
LogWrite 'Connect to VIServer'
#Update - vcenter fqdn should be updated for your environment.
Connect-VIServer vcenter.domain.local -credential $cred




LogWrite ''
LogWrite '#################################Begin cleanup/purge portion of script'
LogWrite 'Confirm "Some VM Folder" folder has existing VMs that match clone naming convention'
LogWrite 'and are over 16 hours old.  If yes, shut off each, and delete.'
LogWrite ''

#Update - Change VM folder per environment.
#Confirm "Some VM Folder" folder has existing VMs that match clone naming convention
#and are over 16 hours old.  If yes, shut off each, and delete.


#Update - Change VM folder per environment.  In my scenario, I maintain a pfsene firewall as an inbound NAT
#option into dev.  I didn't want it deleted with the regular clones, so kept the "| where" exception below.
$vmcheck = get-vm -Location 'Some VM Folder' | where{$_.Name -ne 'VM-to-exclude'} | select Name
$vmcheck2 = $vmcheck | where-object {$_ -match '\d{8}\-\d{6}'} | foreach {$Matches[0]}
if($vmcheck2 -ne $null) {
    $flag = '1'
     
    }else{
    $flag = '0'
     
}

if($flag -eq '0'){
LogWrite 'Unable to locate existing Dev clones'
LogWrite 'Nothing to delete'
LogWrite ''
 
}Else{
LogWrite 'Dev clones found, proceed with shut down and removal'

#Update - Change VM folder per environment.  In my scenario, I maintain a pfsene firewall as an inbound NAT
#option into dev.  I didn't want it deleted with the regular clones, so kept the "| where" exception below.
LogWrite 'Get list of VMs for delete candidate'
$vmlist = get-vm -Location 'Some VM Folder'  | where{$_.Name -ne 'VM-to-exclude'} | select Name
    LogWrite 'Match for cloned VMs'
    LogWrite ''
    foreach($vmls in $vmlist) { 
		#clear vars to resolve bad compare date issue 20191002
        $VMFileName = $null
		$VMFNSplit = $null
		$FileDateStamp = $null
		$var4 = $null
		
        #First confirm that I am working with a cloned VM by looking for 8 characters, then '-', then another 6 chars.
        #The standard clone task naming convention.
        if($vmls -match '\d{8}-\d{6}') {
        LogWrite ('match! '+($vmls.name))
        LogWrite 'Prep variable for compare'   
 
        #Grab datetime format from VM name.
        $VMFileName = $vmls.name
		$VMFNSplit = $VMFileName -split '-'
		$FileDateStamp = [datetime]::ParseExact("$($VMFNSplit[-2])-$($VMFNSplit[-1])",'yyyyMMdd-HHmmss',$null)

		#Get compare date.
		$var4 = (Get-Date).AddHours(-16)
		LogWrite ('Compare Date Base: '+(($var4).tostring('yyyyMMdd-HHmmss'))+' <----Clone has to be older than this date/time')
 		LogWrite ('Compare Date VM  : '+(($FileDateStamp).tostring('yyyyMMdd-HHmmss')))
            #If clone is older than 16 hours, delete it.  Turn this knob based on your requirements.
            if($FileDateStamp -lt $var4) {
            LogWrite 'Outdated clone identified!'
            LogWrite ''
            LogWrite 'Check VM running state'
            #refresh vm variable.  I don't know why you have to do this, but the below running state if statement doesn't work unless you do.
            $vmls = Get-VM -Name $vmls.Name
                if($vmls.PowerState -match 'PoweredOff') {
                LogWrite 'VM not running!'         
					#Delete VM.
					if($vmls.name -match '\d{8}\-\d{6}'){
					remove-vm -VM $vmls.name -DeletePermanently:$true -Confirm:$false

					LogWrite ('Deleted: '+($vmls))
					LogWrite ''
                
					}else{
					LogWrite ('Script just tried to delete none standard clone VM!!!!!')
					LogWrite ''
					echo ('Script just tried to delete none standard clone VM!!!!!: '+($vmls.Name))
					LogWrite ('Exit script, critical error')
					LogWrite ''
					echo ('Exit script, critical error')
			
					#####################End log
					LogWrite '---------------------------->'
					LogWrite 'End PowerCLI-Automate-Dev-VM-Copies.ps1'
					$datetime = Get-Date
					LogWrite ($datetime)
					LogWrite '---------------------------->'
			
					invoke-expression -Command .\ErrorEmail.ps1
			
					EXIT
					}
				
                }else{              
                LogWrite ('VM running!  Will disable HA, force stop and delete. '+($vmls.Name))
				LogWrite ''
                echo ('VM running! '+($vmls.Name)) 
				#Disable HA on VM.
				get-vm $vmls.name | set-vm -HARestartPriority Disabled -confirm:$false | out-null
				#Force VM power off.
				stop-vm -VM $vmls.name -kill -Confirm:$false | out-null
				
					#Delete VM.
					if($vmls.name -match '\d{8}\-\d{6}'){
					remove-vm -VM $vmls.name -DeletePermanently:$true -Confirm:$false
				
					LogWrite ('Deleted: '+($vmls))
					LogWrite ''
				
					}else{
					LogWrite ('Script just tried to delete none standard clone VM!!!!!')
					LogWrite ''
					echo ('Script just tried to delete none standard clone VM!!!!!: '+($vmls.Name))
					LogWrite ('Exit script, critical error')
					LogWrite ''
					echo ('Exit script, critical error')
			
					#####################End log
					LogWrite '---------------------------->'
					LogWrite 'End PowerCLI-Automate-Dev-VM-Copies.ps1'
					$datetime = Get-Date
					LogWrite ($datetime)
					LogWrite '---------------------------->'
					
					invoke-expression -Command .\ErrorEmail.ps1
					
					EXIT
					}
				}
         
            }else{
            LogWrite ('Not older!')
            LogWrite ''
            echo ('Not older!: '+($vmls.Name))
			LogWrite ('Exit script, clones are not old enough to be removed.  Space concerns')
            LogWrite ''
            echo ('Exit script, clones are not old enough to be removed.  Space concerns')
			
			#####################End log
			LogWrite '---------------------------->'
			LogWrite 'End PowerCLI-Automate-Dev-VM-Copies.ps1'
			$datetime = Get-Date
			LogWrite ($datetime)
			LogWrite '---------------------------->'
			
			invoke-expression -Command .\ErrorEmail.ps1
			
			EXIT
            }
                 
        }else{ 
        LogWrite ('No Match found: '+($vmls.Name))
        LogWrite ''
        echo ('No Match found: '+($vmls.Name))
		LogWrite ('Exit script, critical error')
		LogWrite ''
		echo ('Exit script, critical error')
			
		#####################End log
		LogWrite '---------------------------->'
		LogWrite 'End PowerCLI-Automate-Dev-VM-Copies.ps1'
		$datetime = Get-Date
		LogWrite ($datetime)
		LogWrite '---------------------------->'
					
		invoke-expression -Command .\ErrorEmail.ps1
					
		EXIT
        }       
    }
}




#Refresh datastore after removals.
get-datastore -refresh | out-null

#Update - Change VM folder per environment.  In my scenario, I maintain a pfsene firewall as an inbound NAT
#option into dev.  I didn't want it deleted with the regular clones, so kept the "| where" exception below.
$DeleteVerify = get-vm -Location 'Some VM Folder' | where{$_.Name -ne 'VM-to-exclude'}
if($DeleteVerify.count -gt 0){
LogWrite ''
LogWrite ('VMs found in Some VM Folder after purge was supposed to be completed.')
LogWrite ('Critical error, exit script.')

echo 'VMs found in Some VM Folder after purge was supposed to be completed.'
echo 'Critical error, exit script.'
exit
}

LogWrite ''
LogWrite '#############Begin Prod Clone Process'
LogWrite ''
LogWrite 'Read VMList to VMs variable'
#Set var for task completion check later
$taskTab = @{}

#Update - List of prod VMs to clone
$VMs = 'ProdVM1','ProdVM2','ProdVM3','ProdVM4','ProdVM5'
foreach ($VM in $VMs) {
 
LogWrite ('Find current datastore for '+($VM))
#find current datastore and select name, write to variable.
$CurrentDS = Get-Datastore -RelatedObject $VM | select name
$CDS1 = $currentDS.name
LogWrite (($VM)+' datastore identified '+ ($CDS1))
 
#find appropriate destination datastore.
 
<#
Update - In my case I had 3 different storage devices.  You may have more.
The important thing is that the $CPFlag variable gets populated
with a different datastore than the VM is on currently.  You can add
"if" statements as needed.
 
Basically the $CDS1 variable is searched for a string of your choice. 
The common name of a storage device with multiple datastores for example.
if it matches your string, set destination to string of your choice.
#>


#Update - Change source and destination datastores for your environment.
LogWrite 'Find appropriate destination datastore'
$CPFlag = $null
if($CDS1 -match 'SourceDataStoreName') { $CPFlag = 'DestinationDataStoreName' }
#if($CDS1 -match 'Partofdatastorename02') { $CPFlag = 'Fulldatastorename01' }
#if($CDS1 -match 'Partofdatastorename03') { $CPFlag = 'Fulldatastorename01' }

if($CPFlag -eq $null) {
LogWrite ('No suitable destination datastore found, exit job for: '+($VM))

#command used to skip the rest of processing for this object.  Return to next in foreach.
continue

}

LogWrite (($VM)+' will be moved to '+($CPFlag))
 
#Get VM used space
LogWrite ('Find '+($VM)+' used space')
$VMSpace = get-vm $VM | select UsedSpaceGb
$VMSpace2 = $VMSpace | where-object {$_ -match '\d{1,}\.\d{2}'} | foreach {$Matches[0]}
LogWrite (($VM)+' requires '+ ($VMSpace2)+' Gb')
 
#Get destination datastore free space
LogWrite 'Check destination datastore free space'
$DestSpace = get-datastore $CPFlag  | select FreeSpaceGB
$DestSpace2 = $DestSpace | where-object {$_ -match '\d{1,}\.\d{2}'} | foreach {$Matches[0]}
LogWrite (($CPFlag)+' has '+($DestSpace2)+' Gb available')
 
#Math to check available free space
LogWrite ''
$DSAvail = $DestSpace2 - $VMSpace2
LogWrite ('Space after move: '+($DSAvail))
LogWrite ''
 
#if statement if free space check is good, proceed with clone.
LogWrite 'Check if free space on destination datastore is less than 50 Gb after move'
    if($DSAvail -lt '50') {
    echo 'Less Than True!'
    LogWrite '#############'
    LogWrite 'Free space check failed, SKIP clone'
    LogWrite '#############'
    }Else{
    LogWrite '#############'
    LogWrite 'Free space check pass, proceed with clone'
    $vmdatestamp = (Get-Date).tostring('yyyyMMdd-HHmmss')
		
		#Update - You need to enter a valid VMware host here.  It won't necessarily be used to power the VMs on, the command just needs a host.
		#A load evaluation will happen later and the VM will be moved to the least loaded host based on RAM later.
		LogWrite ('Start a-sync clone '+($VM)+' to '+($VM)+'-'+($vmdatestamp))
		$taskTab[(new-vm -Name $VM-$vmdatestamp -VM $VM -Datastore $CPFlag -vmhost host1.domain.local -Location 'Some VM Folder' -runasync).Id] = $Name
		#Refresh datastore space.
		get-datastore -refresh | out-null

    LogWrite '#############'   
    }
 
}

LogWrite ''
LogWrite '#############Check clone status for completion before moving forward with NIC change and Power On.'
LogWrite '#############Check status every 15 minutes'
$runningTasks = $taskTab.Count

DO
{
 
	Get-Task | % {
		if($taskTab.ContainsKey($_.Id) -and $_.State -eq "Success"){
			$taskTab.Remove($_.Id)
			$runningTasks--
		}
	}
	
	if($runningTasks -gt 0){
		Start-Sleep -Seconds 15
	}
	
	LogWrite ''    
	LogWrite ('Clone progress timestamp')
    $datetime = Get-Date
    LogWrite ($datetime)
    LogWrite '#############'
	
} Until ($runningTasks -eq 0)



LogWrite ''
LogWrite '#############Begin Network changes and power on'
LogWrite 'Check VM folder for expected naming convention'

#Update - Set dev network var.  This needs to match a portgroup used for dev workloads.
$DevNet = "DEV-VLAN-68"

#Update - Enter matching VM folder and excluded VM.
$pVMcheck = get-vm -Location 'Some VM Folder' | where{$_.Name -ne 'VM-to-exclude'}
$pVMcheck2 = $pVMcheck | where-object {$_.Name -match '\d{8}'} | foreach {$Matches[0]}
if($pVMcheck2 -ne $null) {
    $pVMflag = '1'
     
    }else{
    $pVMflag = '0'
     
}

if($pVMflag -eq '0'){
LogWrite 'Unable to locate existing Dev clones'
LogWrite 'No VMs to update networking on.'
LogWrite ''
 
}Else{

LogWrite 'Check VM folder for expected naming convention - Pass, proceeding'

$pVMlist = get-vm -Location 'Some VM Folder' | where{$_.Name -ne 'VM-to-exclude'}
foreach($pVM in $pVMlist){
$NetAdapterCheck = $null

LogWrite ''
LogWrite (($pVM.Name)+': Update and confirm networking')
$NetAdapterCheck = get-vm $pVM | get-networkadapter
LogWrite ('Current Network: '+($NetAdapterCheck.NetworkName))
LogWrite 'Updating....'
get-vm $pVM | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $DevNet -Confirm:$false | out-null
$NetAdapterCheck = get-vm $pVM | get-networkadapter
LogWrite ('New Network: '+($NetAdapterCheck.NetworkName))
LogWrite ''
sleep 2
}#end foreach

LogWrite ''
LogWrite '#############Begin Power on sequence'

$pVM1 = get-vm -Location 'Some VM Folder' | where {$_.Name -match 'ProdVM1\-\d{8}\-\d{6}'}
if($pVM1.count -gt 1){
LogWrite ''
LogWrite (($pVM1.Name)+', more than one result.  Environment is not in a healthy state, skip power on')
}else{
	if($pVM1.PowerState -eq 'PoweredOn'){
	LogWrite ''
	LogWrite (($pVM1.Name)+' Already running, skip power on')
	}else{
		#check network one more time before power on.
		LogWrite ''
		LogWrite (($pVM1.Name)+': Check Networking one more time before power on.')
		$pVM1NicCheck1 = get-vm $pVM1 | get-networkadapter
		if($pVM1NicCheck1.NetworkName -eq $DevNet){
		#check pass, Move VM to appropriate host.
		Eval-HostLowRAM
		LogWrite 'check pass, Move VM to appropriate host'
		LogWrite ('host selected: '+($HostLoad.Name))
		get-vm $pVM1.Name | move-vm -destination $HostLoad.Name -confirm:$false | out-null
		#make sure that HA restart is disabled on VM.
		get-vm $pVM1.Name | set-vm -HARestartPriority Disabled -confirm:$false | out-null
		#Power VM on.
		Start-VM -VM $pVM1.Name -Confirm:$false -RunAsync | out-null
		}else{
		LogWrite (($pVM1.Name)+': check DID NOT pass, skip power on.')
		}
	}
}#endif

$pVM2 = get-vm -Location 'Some VM Folder' | where {$_.Name -match 'ProdVM2\-\d{8}\-\d{6}'}
if($pVM2.count -gt 1){
LogWrite ''
LogWrite (($pVM2.Name)+', more than one result.  Environment is not in a healthy state, skip power on')
}else{
	if($pVM2.PowerState -eq 'PoweredOn'){
	LogWrite ''
	LogWrite (($pVM2.Name)+' Already running, skip power on')
	}else{
		#check network one more time before power on.
		LogWrite ''
		LogWrite (($pVM2.Name)+': Check Networking one more time before power on.')
		$pVM1NicCheck2 = get-vm $pVM2 | get-networkadapter
		if($pVM1NicCheck2.NetworkName -eq $DevNet){
		#check pass, Move VM to appropriate host.
		Eval-HostLowRAM
		LogWrite 'check pass, Move VM to appropriate host'
		LogWrite ('host selected: '+($HostLoad.Name))
		get-vm $pVM2.Name | move-vm -destination $HostLoad.Name -confirm:$false | out-null
		#make sure that HA restart is disabled on VM.
		get-vm $pVM2.Name | set-vm -HARestartPriority Disabled -confirm:$false | out-null
		#Power VM on.
		Start-VM -VM $pVM2.Name -Confirm:$false -RunAsync | out-null
		}else{
		LogWrite (($pVM2.Name)+': check DID NOT pass, skip power on.')
		}
	}
}#endif
sleep 600

$pVM3 = get-vm -Location 'Some VM Folder' | where {$_.Name -match 'ProdVM3\-\d{8}\-\d{6}'}
if($pVM3.count -gt 1){
LogWrite ''
LogWrite (($pVM3.Name)+', more than one result.  Environment is not in a healthy state, skip power on')
}else{
	if($pVM3.PowerState -eq 'PoweredOn'){
	LogWrite ''
	LogWrite (($pVM3.Name)+' Already running, skip power on')
	}else{
		#check network one more time before power on.
		LogWrite ''
		LogWrite (($pVM3.Name)+': Check Networking one more time before power on.')
		$pVM1NicCheck3 = get-vm $pVM3 | get-networkadapter
		if($pVM1NicCheck3.NetworkName -eq $DevNet){
		#check pass, Move VM to appropriate host.
		Eval-HostLowRAM
		LogWrite 'check pass, Move VM to appropriate host'
		LogWrite ('host selected: '+($HostLoad.Name))
		get-vm $pVM3.Name | move-vm -destination $HostLoad.Name -confirm:$false | out-null
		#make sure that HA restart is disabled on VM.
		get-vm $pVM3.Name | set-vm -HARestartPriority Disabled -confirm:$false | out-null
		#Power VM on.
		Start-VM -VM $pVM3.Name -Confirm:$false -RunAsync | out-null
		}else{
		LogWrite (($pVM3.Name)+': check DID NOT pass, skip power on.')
		}
	}
}#endif
sleep 120

$pVM4 = get-vm -Location 'Some VM Folder' | where {$_.Name -match 'ProdVM4\-\d{8}\-\d{6}'}
if($pVM4.count -gt 1){
LogWrite ''
LogWrite (($pVM4.Name)+', more than one result.  Environment is not in a healthy state, skip power on')
}else{
	if($pVM4.PowerState -eq 'PoweredOn'){
	LogWrite ''
	LogWrite (($pVM4.Name)+' Already running, skip power on')
	}else{
		#check network one more time before power on.
		LogWrite ''
		LogWrite (($pVM4.Name)+': Check Networking one more time before power on.')
		$pVM1NicCheck4 = get-vm $pVM4 | get-networkadapter
		if($pVM1NicCheck4.NetworkName -eq $DevNet){
		#check pass, Move VM to appropriate host.
		Eval-HostLowRAM
		LogWrite 'check pass, Move VM to appropriate host'
		LogWrite ('host selected: '+($HostLoad.Name))
		get-vm $pVM4.Name | move-vm -destination $HostLoad.Name -confirm:$false | out-null
		#make sure that HA restart is disabled on VM.
		get-vm $pVM4.Name | set-vm -HARestartPriority Disabled -confirm:$false | out-null
		#Power VM on.
		Start-VM -VM $pVM4.Name -Confirm:$false -RunAsync | out-null
		}else{
		LogWrite (($pVM4.Name)+': check DID NOT pass, skip power on.')
		}
	}
}#endif
sleep 120

$pVM5 = get-vm -Location 'Some VM Folder' | where {$_.Name -match 'ProdVM5\-\d{8}\-\d{6}'}
if($pVM5.count -gt 1){
LogWrite ''
LogWrite (($pVM5.Name)+', more than one result.  Environment is not in a healthy state, skip power on')
}else{
	if($pVM5.PowerState -eq 'PoweredOn'){
	LogWrite ''
	LogWrite (($pVM5.Name)+' Already running, skip power on')
	}else{
		#check network one more time before power on.
		LogWrite ''
		LogWrite (($pVM5.Name)+': Check Networking one more time before power on.')
		$pVM1NicCheck5 = get-vm $pVM5 | get-networkadapter
		if($pVM1NicCheck5.NetworkName -eq $DevNet){
		#check pass, Move VM to appropriate host.
		Eval-HostLowRAM
		LogWrite 'check pass, Move VM to appropriate host'
		LogWrite ('host selected: '+($HostLoad.Name))
		get-vm $pVM5.Name | move-vm -destination $HostLoad.Name -confirm:$false | out-null
		#make sure that HA restart is disabled on VM.
		get-vm $pVM5.Name | set-vm -HARestartPriority Disabled -confirm:$false | out-null
		#Power VM on.
		Start-VM -VM $pVM5.Name -Confirm:$false -RunAsync | out-null
		}else{
		LogWrite (($pVM5.Name)+': check DID NOT pass, skip power on.')
		}
	}
}#endif

}#end if

#Update - change cleanup path to match your scripting directory.
LogWrite 'Clear log files older than 3 days'
forfiles -p "C:\Scripts\owerCLI-Automate-Dev-VM-Copies" -s -m *.log /D -3 /C "cmd /c del @path"

LogWrite 'Send Email'

#####################End log
LogWrite '---------------------------->'
LogWrite 'End PowerCLI-Automate-Dev-VM-Copies.ps1'
$datetime = Get-Date
LogWrite ($datetime)
LogWrite '---------------------------->'

#Update - Enter vcenter server name per your environment.
LogWrite 'Disconnect vCenter Server'
Disconnect-VIServer vcenter.domain.local -Confirm:$false

#Begin Email with attached log'

#Update - Collect new creds for mail relay.
$pwd2 = Get-Content RelayCred | ConvertTo-SecureString
$cred2 = New-Object System.Management.Automation.PsCredential $username, $pwd2

# Send email
$emailSmtpServer = "mail.domain.com"
$emailSmtpServerPort = "25"
$emailSmtpUser = "domain\username"
$emailSmtpPass = $pwd2
 
$emailMessage = New-Object System.Net.Mail.MailMessage
$emailMessage.From = "username@domain.com"
$emailMessage.To.Add( "recipientuser@domain.com")
$emailMessage.Subject = "PowerCLI-Automate-Dev-VM-Copies.ps1"
$emailMessage.IsBodyHtml = $true
$emailMessage.Body = @"
<p>PowerCLI-Automate-Dev-VM-Copies.ps1 Log - vCenter Server hostname</strong>.<br>
 <br>
 See attached log file.<br>
By Adam Tyler</p>
"@
 
$SMTPClient = New-Object System.Net.Mail.SmtpClient( $emailSmtpServer , $emailSmtpServerPort )
$SMTPClient.EnableSsl = $true
$SMTPClient.Credentials = New-Object System.Net.NetworkCredential( $emailSmtpUser , $emailSmtpPass );

$attachment = (($PSScriptRoot)+'\'+($Logfile))
$emailMessage.Attachments.Add( $attachment )
 
$SMTPClient.Send( $emailMessage )
 
#EXIT
