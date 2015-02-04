$vShieldInstallFile = "C:\Temp\VMware-vShield-Manager-5.5.3-2175697.ova"
$vShieldName = "VCNS01"
$vShieldNetwork = "VM Network"
$vShieldIP = "192.168.1.210"
$vShieldSNM = "255.255.255.0"
$vShieldDGW = "192.168.1.1"
$vShieldDNS = "192.168.1.1"
$vShieldCluster = "Home-Cluster"
$vShieldPassword = "VMware1!"
$vShieldvC = "192.168.1.200"
$vShieldvCUser = "Administrator@vsphere.local"
$vShieldvCPass = "VMware1!"
	
if (!(get-pssnapin -name VMware.VimAutomation.Core -erroraction 'SilentlyContinue')) {
	Write-Host "[INFO] Adding PowerCLI Snapin"
	add-pssnapin VMware.VimAutomation.Core -ErrorAction 'SilentlyContinue'
	if (!(get-pssnapin -name VMware.VimAutomation.Core -erroraction 'SilentlyContinue')) {
		Write-Host "[ERROR] PowerCLI Not installed, please install from Http://VMware.com/go/PowerCLI"
	} Else {
		Write-Host "[INFO] PowerCLI Snapin added"
	}
    Connect-VIServer $vShieldvC -User $vShieldvCUser -Password $vShieldvCPass
}
	
$vShieldSpaceNeededGB = "5"
Write-Host "[INFO] Selecting host for $vShieldName from $vShieldCluster Cluster"
$vShieldVMHost =  Get-Cluster $vShieldCluster | Get-VMHost | Where {$_.PowerState -eq "PoweredOn" -and $_.ConnectionState -eq "Connected" } | Get-Random
Write-Host "[INFO] $vShieldVMHost selected for $vShieldName"
Write-Host "[INFO] Selecting Datastore for $vShieldName"
$vShieldDatastore = $vShieldVMHost | Get-Datastore | Where {$_.ExtensionData.Summary.MultipleHostAccess} | Where {$_.FreeSpaceGB -ge $vShieldSpaceNeededGB} | Get-Random
if (!$vshieldDatastore) { Write-Host "[ERROR] No Available Shared datastores with $vShieldSpaceNeededGB GB available" ; Exit }
Write-Host "[INFO] $vShieldDatastore selected for $vShieldName"

$Settings = Get-OvfConfiguration $vShieldInstallFile
$Settings.NetworkMapping.VSMgmt.value = $vShieldNetwork
$Settings.Common.vsm_cli_en_passwd_0.value = $vShieldPassword
$Settings.Common.vsm_cli_passwd_0.value = $vShieldPassword

Write-Host "[INFO] Importing $vShieldName from $vShieldInstallFile"
$vShieldDeployedVMTask = $vShieldVMHost | Import-vApp -OvfConfiguration $Settings -Name $vShieldName -Source $vShieldInstallFile -Datastore $vShieldDatastore -Force -RunAsync
do {
	Sleep 1
    Write-progress -Activity "Deploying $vShieldName" -PercentComplete $($vShieldDeployedVMTask.PercentComplete) -Status "$($vShieldDeployedVMTask.PercentComplete)% completed"
		
} until ($vShieldDeployedVMTask.PercentComplete -eq 100 )
Write-Host "[INFO] $vShieldName deployed and the task result was $($vShieldDeployedVMTask.State)"

If ($vShieldDeployedVMTask.State -ne "success") {
		Write-Host "[ERROR] Unable to deploy vShield, deploy failed with $($vShieldDeployedVMTask.TerminatingError)"
        Exit
} Else {
    $vShieldDeployedVM = Get-VM $vShieldName
    	
	$NetworkChange = $vShieldDeployedVM | Get-NetworkAdapter 
    If ($NetworkChange.NetworkName -ne $vShieldNetwork) {
        Write-Host "[INFO] Reconfiguring Network on $vShieldName to join $vShieldNetwork"
        $NetworkChange | Set-NetworkAdapter -NetworkName $vShieldNetwork -Confirm:$false
    }
	$key = "machine.id" 
	$value = "ip_0={0}&gateway_0={1}&computerName={2}&netmask_0={3}&markerid=1&reconfigToken=1" -f $vShieldIP, $vShieldDGW, $vShieldName, $vShieldSNM
	$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec 
	$vmConfigSpec.extraconfig += New-Object VMware.Vim.optionvalue 
	$vmConfigSpec.extraconfig[0].Key=$key 
	$vmConfigSpec.extraconfig[0].Value=$value 

	Write-Host "[INFO] Reconfiguring $vShieldName after deployment"
	$SetConfig = $vShieldDeployedVM.ExtensionData.ReconfigVM_Task($vmConfigSpec) 	
    Write-Host "[INFO] Power On $vShieldName for first time"
	$vShieldDeployedVM | Start-VM | Out-Null
	Write-Host "[INFO] $vShieldName deployment and configuration completed."
}
