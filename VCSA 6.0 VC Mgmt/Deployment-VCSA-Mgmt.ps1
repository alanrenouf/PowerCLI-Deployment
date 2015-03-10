# Author: William Lam
# Site: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2015/01/ultimate-automation-guide-to-deploying-vcsa-6-0-part-4-vcenter-server-management-node.html

# Load OVF/OVA configuration into a variable
$ovffile = "Z:\Storage\Images\Beta\VMware-VCSA-all-6.0.0-2497477\vcsa\vmware-vcsa.ova"
$ovfconfig = Get-OvfConfiguration $ovffile

# vSphere Cluster + VM Network configurations
$Cluster = "Mini-Cluster"
$VMName = "PS-vcsa-01"
$VMNetwork = "VM Network"

$VMHost = Get-Cluster $Cluster | Get-VMHost | Sort MemoryGB | Select -first 1
$Datastore = $VMHost | Get-datastore | Sort FreeSpaceGB -Descending | Select -first 1
$Network = Get-VirtualPortGroup -Name $VMNetwork -VMHost $vmhost

# Fill out the OVF/OVA configuration parameters

# vSphere Portgroup Network Mapping
$ovfconfig.NetworkMapping.Network_1.value = $Network

# tiny,small,medium,large,management-tiny,management-small,management-medium,management-large,infrastructure
$ovfconfig.DeploymentOption.value = "management-tiny"

# IP Protocol
$ovfconfig.IpAssignment.IpProtocol.value = "IPv4"

# IP Address Family
$ovfconfig.Common.guestinfo.cis.appliance.net.addr.family.value = "ipv4"

# IP Address Mode
$ovfconfig.Common.guestinfo.cis.appliance.net.mode.value = "static"

# IP Address 
$ovfconfig.Common.guestinfo.cis.appliance.net.addr_1.value = "192.168.1.72"

# IP PNID (same as IP Address if there's no DNS)
$ovfconfig.Common.guestinfo.cis.appliance.net.pnid.value  = "192.168.1.72"

# IP Network Prefix (CIDR notation)
$ovfconfig.Common.guestinfo.cis.appliance.net.prefix.value = "24"

# IP Gateway
$ovfconfig.Common.guestinfo.cis.appliance.net.gateway.value = "192.168.1.1"

# DNS
$ovfconfig.Common.guestinfo.cis.appliance.net.dns.servers.value = "192.168.1.1"

# Root Password
$ovfconfig.Common.guestinfo.cis.appliance.root.passwd.value = "VMware1!"

# Enable SSH
$ovfconfig.Common.guestinfo.cis.appliance.ssh.enabled.value = "True"

# SSO Domain Name
$ovfconfig.Common.guestinfo.cis.vmdir.domain_name.value = "vghetto.local"

# SSO Site Name
$ovfconfig.Common.guestinfo.cis.vmdir.site_name.value = "vghetto"

# SSO Admin Password 
$ovfconfig.Common.guestinfo.cis.vmdir.password.value = "VMware1!"

# NTP Servers
$ovfconfig.Common.guestinfo.cis.appliance.ntp.servers.value = "0.pool.ntp.org"

# PSC Node
$ovfconfig.Common.guestinfo.cis.system.vm0.hostname.value = "192.168.1.70"

# Deploy the OVF/OVA with the config parameters
Import-VApp -Source $ovffile -OvfConfiguration $ovfconfig -Name $VMName -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin
