# Author: William Lam
# Site: www.virtuallyghetto.com
# Description: Script to deploy vRA 7 Virtual Appliance
# Reference: http://www.virtuallyghetto.com/2016/02/automating-vrealize-automation-7-simple-install-part-1-vra-appliance-deployment.html

# Load OVF/OVA configuration into a variable
$ovffile = "C:\Users\primp\Desktop\VMware-vR-Appliance-7.0.0.1460-3311738_OVF10.ova"
$ovfconfig = Get-OvfConfiguration $ovffile

# vSphere Cluster + VM Network configurations
$Cluster = "Primp-Cluster"
$VMName = "vRA-Appliance"
$VMNetwork = "access333"

$VMHost = Get-Cluster $Cluster | Get-VMHost | Sort MemoryGB | Select -first 1
$Datastore = $VMHost | Get-datastore | Sort FreeSpaceGB -Descending | Select -first 1
$Network = Get-VirtualPortGroup -Name $VMNetwork -VMHost $vmhost

# Fill out the OVF/OVA configuration parameters

# vSphere Portgroup Network Mapping
$ovfconfig.NetworkMapping.Network_1.value = $Network

# IP Protocol
$ovfconfig.IpAssignment.IpProtocol.value = "IPv4"

# IP Address
$ovfConfig.vami.VMware_vRealize_Appliance.ip0.value = "172.30.0.180"

# Netmask
$ovfConfig.vami.VMware_vRealize_Appliance.netmask0.value = "255.255.255.0"

# Gateway
$ovfConfig.vami.VMware_vRealize_Appliance.gateway.value = "172.30.0.1"

# DNS Server
$ovfConfig.vami.VMware_vRealize_Appliance.DNS.value = "172.30.0.100"

# DNS Domain
$ovfConfig.vami.VMware_vRealize_Appliance.domain.value  = "primp-industries.com"

# DNS Search Path
$ovfConfig.vami.VMware_vRealize_Appliance.searchpath.value = "primp-industries.com"

# OS Password
$ovfconfig.common.varoot_password.value = "VMware1!"

# Enable SSH
$ovfconfig.common.va_ssh_enabled.value = "True"

# Deploy the OVF/OVA with the config parameters
Import-VApp -Source $ovffile -OvfConfiguration $ovfconfig -Name $VMName -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin
