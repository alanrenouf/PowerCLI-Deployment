# Author: Tommy McNicholas
# Site: vmvortex.com
# Smashed together code from William Lam, Brian Graf, and Alan Renouf, to deploy NSX Manager 6.2.X
# Reference: TBA

# Load OVF/OVA configuration into a variable
$ovffile = "Z:\Storage\Images\VMware-NSX-Manager-6.2.3-3979471.ova"
$ovfconfig = Get-OvfConfiguration $ovffile

# OVA Deployment Target vSphere Cluster and Network configurations
$Cluster = "Mini-Cluster"
$VMName = "PS-psc-01"
$VMNetwork = "VM Network"
$VMIpaddress = "192.168.1.78"
$VMNetmask = "255.255.255.0"
$VMGateway = "192.168.1.1"
$VMDnsServer1 = "192.168.1.1"
$VMDomain = "vghetto.local"
$NSXPass = "VMware1!"

$VMHost = Get-Cluster $Cluster | Get-VMHost | Sort MemoryGB | Select -first 1
$Datastore = $VMHost | Get-datastore | Sort FreeSpaceGB -Descending | Select -first 1
$Network = Get-VirtualPortGroup -Name $VMNetwork -VMHost $vmhost

# Target vCenter environment the NSX Manager will attach to, may or may not be a different vCenter than the VM lives in!
$Targetvc = "PS-vcsa-01.vghetto.local"
$Targetvcuser = "Administrator@vghetto.local"
$Targetvcpass = "VMware1!"
$Targetvcversion = 6
$Targetvcexternalpsc = "True"
$Targetvcpsc = "PS-psc-01.vghetto.local"

#!!! You shouldn't have to change anything below this point !!!

# Ignore SSL Errors
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

#Get the vCenter Certificate first, we need this regardless
$Port = "443"
$Timeoutms = "3000"
    Write-verbose "$Targetvc`: Connecting on port $port"
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $req = [Net.HttpWebRequest]::Create("https://$Targetvc`:$port/")
    $req.Timeout = $Timeoutms
    try {$req.GetResponse() | Out-Null} catch {write-error "Couldn't connect to $Targetvc on port $port"; continue}
    if (!($req.ServicePoint.Certificate)) {write-error "No Certificate returned on $Targetvc"; continue}
    $certinfo = $req.ServicePoint.Certificate

    $returnobj = [ordered]@{
        ComputerName = $Targetvc;
        Port = $port;
        Subject = $certinfo.Subject;
        Thumbprint = $certinfo.GetCertHashString();
        Issuer = $certinfo.Issuer;
        SerialNumber = $certinfo.GetSerialNumberString();
        Issued = [DateTime]$certinfo.GetEffectiveDateString();
        Expires = [DateTime]$certinfo.GetExpirationDateString();
    }

#Add the delimiters to vCenter SSL thumbprint
$Targetvcthumbprint = ($returnobj.Thumbprint -replace '(..)','$1:').trim(':')

#Check for an external PSC flag, and if so, get the external PSC thumbprint, and set SSO variables
If ($Targetvcexternalpsc -eq "True"){
  $Port = "443"
  $Timeoutms = "3000"
      Write-verbose "$Targetvcpsc`: Connecting on port $port"
      [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
      $req = [Net.HttpWebRequest]::Create("https://$Targetvcpsc`:$port/")
      $req.Timeout = $Timeoutms
      try {$req.GetResponse() | Out-Null} catch {write-error "Couldn't connect to $Targetvcpsc on port $port"; continue}
      if (!($req.ServicePoint.Certificate)) {write-error "No Certificate returned on $Targetvcpsc"; continue}
      $certinfo = $req.ServicePoint.Certificate

      $returnobj = [ordered]@{
          ComputerName = $Targetvcpsc;
          Port = $port;
          Subject = $certinfo.Subject;
          Thumbprint = $certinfo.GetCertHashString();
          Issuer = $certinfo.Issuer;
          SerialNumber = $certinfo.GetSerialNumberString();
          Issued = [DateTime]$certinfo.GetEffectiveDateString();
          Expires = [DateTime]$certinfo.GetExpirationDateString();
      }
      #Add the delimiters to the PSC SSL thumbprint
      $Targetvcpscthumbprint = ($returnobj.Thumbprint -replace '(..)','$1:').trim(':')
      #Since we have a PSC, set the SSO target to the PSC
      $Targetsso = $Targetvcpsc
      $Targetssothumbprint = $Targetvcpscthumbprint
      } Else {
        $Targetsso = $Targetvc
        $Targetssothumbprint = $Targetvcthumbprint
}

# Fill out the OVF/OVA configuration parameters
# vSphere Portgroup Network Mapping
$ovfconfig.NetworkMapping.VSMgmt.value = $VMNetwork

# IP Address
$ovfconfig.Common.vsm_ip_0.value = $VMIpaddress

# Virtual Machine Name
$ovfconfig.Common.vsm_hostname.value  = $VMName

# IP Network Mask
$ovfconfig.Common.vsm_netmask_0.value = $VMNetmask

# IP Gateway
$ovfconfig.Common.vsm_gateway_0.value = $VMGateway

# DNS
$ovfconfig.Common.vsm_dns1_0.value = $VMDnsServer1

# Domain
$ovfconfig.Common.vsm_domain_0.value = $VMDomain

# CLI and Enable Passwords
$ovfconfig.Common.vsm_cli_passwd_0.value = $NSXPass
$ovfconfig.Common.vsm_cli_en_passwd_0.value = $NSXPass

# Enable SSH
$ovfconfig.Common.vsm_isSSHEnabled.value = "True"

# NTP Servers
$ovfconfig.Common.vsm_ntp_0.value = "0.pool.ntp.org"

# Deploy the OVF/OVA with the config parameters
Import-VApp -Source $ovffile -OvfConfiguration $ovfconfig -Name $VMName -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin

# Start the NSX Manager Virtual Machine
Start-VM -VM $VMName -Confirm:$false

# Wait for VMware tools to start, indicating the VM is ready for command
$VM_View = get-vm $vmname | get-view
$toolsstatus = $VM_View.Summary.Guest.ToolsRunningStatus
write-host "waiting for $vmname to boot up" -foregroundcolor 'Yellow'
do {
Sleep -seconds 20
$VM_View = get-vm $vmname | get-view
$toolsstatus = $VM_View.Summary.Guest.ToolsRunningStatus
} Until ($toolsstatus -eq "guestToolsRunning")

Write-Host "$vmname has booted up successfully, Proceeding" -foregroundcolor 'Green'
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "admin",$NSXPass)))
$header = @{Authorization=("Basic {0}" -f $base64AuthInfo)}
 $uri = "https://$VMIpaddress/api/2.0/vdn/controller"
do {
	Start-Sleep -Seconds 20
	$result = try { Invoke-WebRequest -Uri $uri -Headers $header -ContentType "application/xml"} catch { $_.Exception.Response}
} Until ($result.statusCode -eq "200")

Write-Host "Connected to $VMIpaddress successfully."

# Connect NSX Manager to vCenter
Write-Host "Attempting to connect NSX Manager to vCenter" -ForegroundColor Yellow

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "admin",$NSXPass)))
$header = @{Authorization=("Basic {0}" -f $base64AuthInfo)}
$uri="https://$VMIpaddress/api/2.0/services/vcconfig"

[XML] $body = "<vcInfo>
 <ipAddress>$Targetvc</ipAddress>
 <userName>$Targetvcuser</userName>
 <password>$Targetvcpass</password>
 <certificateThumbprint>$Targetvcthumbprint</certificateThumbprint>
</vcInfo>
"
Invoke-RestMethod -Uri $uri -Method "Put" -Headers $header -ContentType "application/xml" -Body $body

#Make a happy comment about successfully completing the connection
Write-Host "Connected $VMName to vCenter $Targetvc!" -ForegroundColor Green

# Check the version of vCenter to set the right port for SSO registration
If ($Targetvcversion -lt 6) {
  Write-Host "$Targetvc is earlier than vCenter v6.X, creating the URI for SSO to port 7444"
  $Targetssouri = "https://{0}:7444/lookupservice/sdk" -f $Targetsso
  Write-Host "SSO URL is $Targetssouri" -ForegroundColor Green
} Else {
  Write-Host "$Targetvc is vCenter v6.X or newer, checking for external PSC flag"
  If ($Targetvcexternalpsc -eq "True") {
    Write-Host "External PSC defined as $Targetvcpsc"
    $Targetssouri = "https://{0}:443/lookupservice/sdk" -f $Targetsso
    Write-Host "SSO URL is $Targetssouri" -ForegroundColor Green
  } Else {
    Write-Host "No External PSC found, using $Targetvc for SSO"
    $Targetssouri = "https://{0}:443/lookupservice/sdk" -f $Targetsso
    Write-Host "SSO URL is $Targetssouri" -ForegroundColor Green
 }
}

# Configure SSO

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "admin",$NSXPass)))
$header = @{Authorization=("Basic {0}" -f $base64AuthInfo)}
$uri="https://$VMIpaddress/api/2.0/services/ssoconfig"

[XML] $body = "<ssoConfig>
 <ssoLookupServiceUrl>$Targetssouri</ssoLookupServiceUrl>
 <ssoAdminUsername>$Targetvcuser</ssoAdminUsername>
 <ssoAdminUserpassword>$Targetvcpass</ssoAdminUserpassword>
 <certificateThumbprint>$Targetssothumbprint</certificateThumbprint>
</ssoConfig>
"

Invoke-RestMethod -Uri $uri -Method "Post" -Headers $header -ContentType "application/xml" -Body $body

# Make a happy comment about successfully completing the connection
Write-Host "Connected $VMName to SSO lookup service on $Targetsso !" -ForegroundColor Green
