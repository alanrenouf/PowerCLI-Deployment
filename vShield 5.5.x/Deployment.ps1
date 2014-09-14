# Load OVF/OVA configuration into a variable  
$ovffile = "C:\Software\VMware-vShield-Manager-5.5.3-2081508.ova"  
$ovfconfig = Get-OvfConfiguration $ovffile  
   
# Get the values to use for deployment  
$VMHost = Get-Cluster "Cluster Site A" | Get-VMHost | Sort MemoryGB | Select -first 1  
$Datastore = $VMHost | Get-datastore | Sort FreeSpaceGB -Descending | Select -first 1  
$Network = Get-VirtualPortGroup -Name "VM Network" -VMHost $vmhost    
$VMName = "VSM01"
$vsmip = "192.168.110.150"
$vsmgateway = "192.168.110.1"
$vsmnetmask = "255.255.255.0"
$vsmhostname = $VMName
 
# Fill out the OVF/OVA configuration parameters   
$ovfconfig.NetworkMapping.VSMgmt.value = $Network   
$ovfconfig.Common.vsm_cli_passwd_0.value = "VMware1!"  
$ovfconfig.Common.vsm_cli_en_passwd_0.value = "VMware1!" 

# Deploy the OVF/OVA with the config parameters  
$VSMVM = Import-VApp -Source $ovffile -OvfConfiguration $ovfconfig -Name $VMName -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin  

# Set the IP Address
$key = "machine.id"
$value = "ip_0={0}&gateway_0={1}&computerName={2}&netmask_0={3}&markerid=1&reconfigToken=1" -f $vsmip, $vsmgateway, $vsmhostname, $vsmnetmask 

$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec 
$vmConfigSpec.extraconfig += New-Object VMware.Vim.optionvalue 
$vmConfigSpec.extraconfig[0].Key=$key 
$vmConfigSpec.extraconfig[0].Value=$value 
$ApplyIP = $vsmvm.ExtensionData.ReconfigVM_Task($vmConfigSpec) 

 