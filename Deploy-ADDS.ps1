<#
.Synopsis
This Script will deploy the First Domain Controller in your Forest.

.Description
Script will help you to do the following:
    Assign the Network Card configuration
    Disable the Windows Firewall if needed
    Rename the Server if needed
    Install the prerequisites required for ADDS
    Test if the server ready for ADDS Service or not
    Install First Domain Controller in the Forest

.Notes
    Author: Fady Naguib
    Copyright: By Fady naguib, March 2018
               Can be used and distributed
    Initial Release: 3/21/2018 
#>

Write-host "This Script will install your first Domain Controller in the Forest`
" -ForegroundColor Cyan
sleep 1
Function Go-Home 
{
Write-Host "Please choose the Module you want to execute:`
" -ForegroundColor yellow
Write-Host "
1- Setting IP and DNS Configuration for Network Interface`
2- Disable Windows Firewall Profiles`
3- Rename the Server
4- Install Prerequisites for ADDS Service
5- Test and Install ADDS Service"
$Selcetion = Read-Host "Please choose a Module"
Switch($Selcetion) {
'1' { Config-Network }
'2' { Config_Firewall }
'3' { Rename-Server }
'4' { Install-ADDS-Feature }
'5' { Install-ADDS }
}
}



# Configure Network Card
Function Config-Network 
{
$NIC_List = @()
$NICs = (Get-NetAdapter).InterfaceAlias
$NIC_List += $NICs 
Write-Host "We have following Network Interface(s) on the Server:" -ForegroundColor Cyan
$NIC_List

$NIC_Name = Read-Host "Please Enter Network Interface name that will be used from the above list"
$NIC_ID = (Get-NetAdapter -Name $NIC_Name).InterfaceIndex
$Dis_IPV6 = Read-Host "Would you like to Disable IPv6 on $Nic_Name Adapter? Y / N"
switch ($Dis_IPV6)
{
    'Y' {
        Disable-NetAdapterBinding -Name $NIC_Name -ComponentID ms_tcpip6
               $IPV6_State = Get-NetAdapterBinding -Name $NIC_Name | where {$_.ComponentId -like "ms_tcpip6"}
            if ($IPV6_State.Enabled -like "False")
            { Write-Host "IPV6 has been disabled on $NIC_Name`
            `
            " -ForegroundColor Green
            }
            else
            { Write-Host "IPV6 failed to disabled. You Can discard it and disable it manually later" -ForegroundColor Magenta
            }
        }
   
    'N' {Write-Host "Disabling IPV6 has been discarded" -ForegroundColor Magenta}
    
}

#Check if DHCP Enabled on the Network Interface
$DHCP_Status = (Get-NetIPInterface -InterfaceIndex $NIC_ID).DHCP
    if($DHCP_Status -eq "Enabled") 
    {
     Write-Host "Domain Controller should has Static IP address"  -ForegroundColor Yellow
     Write-Host "We will configure the NIC $NIC_Name with Static IP Address. Please fill below to continue" -ForegroundColor Cyan

     $IP_Add = Read-Host "Enter the IPv4 Address"
     $Mask = Read-Host "Enter the Subnet Mask Lenght (e.g. 16 or 24)"
     $GW = Read-Host "Enter the Default Gateway"
     Write-Host "You can add 2 DNS Servers IP Addresses separated by ','" -ForegroundColor Yellow
     $Pref_DNS = Read-Host "Enter DNS Server(s) IP Address" 
     Write-Host "Assigning Network Configuration to $NIC_Name Adapter" -ForegroundColor Cyan
     New-NetIPAddress -InterfaceAlias $Nic_Name -IPAddress $IP_Add -PrefixLength $Mask -DefaultGateway $GW -AddressFamily IPv4 | Out-Null
     Set-DnsClientServerAddress -InterfaceAlias $NIC_Name -ServerAddresses $Pref_DNS | Out-Null

     Get-WmiObject Win32_NetworkAdapterConfiguration | where {$_.InterfaceIndex -eq $NIC_ID} | Select @{Name='IP Address';Expression={$_.IPAddress}}, @{Name='Subnet Mask';Expression={$_.IPSubnet}},@{Name='Default Gateway';Expression={$_.DefaultIPGateway}}, @{Name='DNS Server';Expression={$_.DNSServerSearchOrder}} | Format-List *

    }
    else 
    {
        Write-host "Here is the current Network Configuration on $NIC_Name"
        Get-WmiObject Win32_NetworkAdapterConfiguration | where {$_.InterfaceIndex -eq $NIC_ID} | Select @{Name='IP Address';Expression={$_.IPAddress}}, @{Name='Subnet Mask';Expression={$_.IPSubnet}},@{Name='Default Gateway';Expression={$_.DefaultIPGateway}}, @{Name='DNS Server';Expression={$_.DNSServerSearchOrder}} | Format-List *
        $IP_Deci = Read-Host "Would you like to keep the current configuration? Y /N" 
        Switch($IP_Deci){
            'Y'{ Go-Home }
            'N' { 
                Write-Host "We will configure the NIC $NIC_Name with Static IP Address. Please fill below to continue" -ForegroundColor Cyan
                [String]$Ext_GW = (Get-WmiObject Win32_NetworkAdapterConfiguration | where {$_.InterfaceIndex -eq $NIC_ID}).DefaultIPGateway
                Remove-NetIPAddress -InterfaceIndex $NIC_ID -DefaultGateway $Ext_GW -IncludeAllCompartments -Confirm:$false
                Set-DnsClientServerAddress -InterfaceIndex $NIC_ID -ResetServerAddresses
                
                $IP_Add = Read-Host "Enter the IPv4 Address"
                $Mask = Read-Host "Enter the Subnet Mask Lenght (e.g. 16 or 24)"
                $GW = Read-Host "Enter the Default Gateway"
                Write-Host "You can add 2 DNS Servers IP Addresses separated by ','" -ForegroundColor Yellow
                $Pref_DNS = Read-Host "Enter DNS Server(s) IP Address" 
                Write-Host "Assigning Network Configuration to $NIC_Name Adapter" -ForegroundColor Cyan
                New-NetIPAddress -InterfaceAlias $Nic_Name -IPAddress $IP_Add -PrefixLength $Mask -DefaultGateway $GW -AddressFamily IPv4 | Out-Null
                Set-DnsClientServerAddress -InterfaceAlias $NIC_Name -ServerAddresses $Pref_DNS | Out-Null

                Get-WmiObject Win32_NetworkAdapterConfiguration | where {$_.InterfaceIndex -eq $NIC_ID} | Select @{Name='IP Address';Expression={$_.IPAddress}}, @{Name='Subnet Mask';Expression={$_.IPSubnet}},@{Name='Default Gateway';Expression={$_.DefaultIPGateway}}, @{Name='DNS Server';Expression={$_.DNSServerSearchOrder}} | Format-List *

                }
    }

}

Go-Home
}

# Disable Windows Firewall Profiles
Function Config_Firewall
{
Write-Host "We will work with the Windows Firewall Settings" -ForegroundColor Cyan
$FW_Status = Get-NetFirewallProfile -Name Domain,Public,Private
if($FW_Status.Enabled -eq $true) 
{
$FW_Deci = Read-Host "Windows Firewall Profiles are enabled. Would you like to disable them? Y / N"
    switch($FW_Deci) {
    'Y' {Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
         Get-NetFirewallProfile -Name Domain,Public,Private | select @{Name='Profile Name';expression={$_.Name}},@{Name='Status';expression={$_.Enabled}} | FL *
         }
    'N'{Write-Host "Please confirm that you have required Firewall rules"-ForegroundColor Yellow }
     }
}
else 
{ 
      Write-host "Windows Firewall profiles already disabled" -ForegroundColor Cyan
      Get-NetFirewallProfile -Name Domain,Public,Private | select @{Name='Profile Name';expression={$_.Name}},@{Name='Status';expression={$_.Enabled}} | FL *
}

Sleep 2
Go-Home
}


# Rename the server#
Function Rename-Server

 {
$Comp_Name = hostname
$Decision = Read-Host "Server Name is $Comp_Name, Do you want to rename the server? Y / N"
    switch ($Decision)
    {
        'Y' 
        {
        [string]$New_Name = Read-Host "Enter a New Name"
            if ($New_Name.Length -gt 15)
            {
                 Write-Host "Server Name should be less tahn 15 characters" -ForegroundColor Yellow
                 $New_Name = Read-Host "Enter a New Name"
            }
        Rename-Computer -NewName $New_Name -PassThru
        $Reboot = Read-Host "Do you want to restart it now? Y / N"
            if ($Reboot -eq "Y")
            {
            Restart-Computer -Force
            }
            Else {
            Write-Host "Please reboot the server before installing Active Directory Domain Service" -ForegroundColor Yellow
            }
        }

        
        'N' {
        Write-Host "Domain Controller Name will be $Comp_Name" -ForegroundColor Magenta
            }
        
    }
Sleep 2
Go-Home
}


# Install Windows Features required for ADDS
Function Install-ADDS-Feature
{
Write-Host "The Script will install ADDS Windows Feature on the Server" -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Out-Null
Sleep 2
Go-Home
}


Function Install-ADDS
{
Write-Host "First, The Script will test the forest prerequisites before installation"
Write-Host "Note: You will be prompted to enter the Safe Mode password" -ForegroundColor Yellow 
$Domain_FQDN = Read-Host "Please enter your Forest Fully Qualified Domain Name"
$Domain_NetBios = Read-Host "Please Enter the NetBios Name of the Domain"
Import-Module ADDSDeployment 
Write-Host "Here is the Function Level values for Forest Mode and Domain Mode
Fuction Level           Numeric Valuve
=============           ==============
Windows Server 2003     2
Windows Server 2008     3
Windows Server 2008R2   4
Windows Server 2012     5
Windows Server 2012R2   6
Windows Serve-r 2016    7" -ForegroundColor Green
$Forest_FL = Read-Host "Please Enter the numeric value expected for your Forest"
$Domain_FL = Read-Host "Please Enter the numeric value expected for your Domain"
$Safe_Mode_PSW = Read-Host "Enter the Active Directory Safe Mode Password" -AsSecureString
$Forest_Test = Test-ADDSForestInstallation -DomainName $Domain_FQDN -DomainNetbiosName $Domain_NetBios -ForestMode $Forest_FL -DomainMode $Domain_FL -SafeModeAdministratorPassword $Safe_Mode_PSW -NoDnsOnNetwork -WarningAction Ignore -WarningVariable Warning_Forest -ErrorVariable Failed_Forest -Force
if($Failed_Forest) { Write-Host $Failed_Forest}
$Forest_Result = $Forest_Test.Status -as [String]
    If($Forest_Test.Status -eq "Success")
    {
        Write-Host "Forest prerequisites have been passed successfully
Forest Test Result: $Forest_Result" -ForegroundColor Cyan 
$Inst = Read-Host "Would you like to proceed and deploy the Domain? Y / N"
Switch($Inst)
 {
    'Y' 
    { 
    Install-ADDSForest -DomainName $Domain_FQDN -DomainNetBiosName $Domain_NetBios -DomainMode $Domain_FL -SafeModeAdministratorPassword $Safe_Mode_PSW -ForestMode $Forest_FL -NoDnsOnNetwork -WarningAction Ignore -Force
    }
    'N'
    {
    Write-Host "You can deploy your Domain Later. Thank you" -ForegroundColor Green
    }
 }
    Else 
    {
    Write-Host "Forest test Failed" -ForegroundColor Yellow
    $Failed_Forest 
    }

}
}
Go-Home