<#

.SYNOPSIS
This script can be used create single IP4 Reservations for Proteus Bluecat Address Manager. API Documentation can be found at http://timlossev.com/attachments/Proteus_API_Guide_3.7.1.pdf

.Description
Published 3/24/2020. Confluence Health. Author David Belmont. Utilizing the Proteus BAM API this script can either create a single reservation or import a batch of reservations. Imports must be a csv format [mac,IPName,ObjectType] with no headers.

.Example
Single Import:

    Create-ProteusIP4Object -UserName e12345a -Password [ENTER YOUR PASSWORD] -Subnet '172.100.10.0' -MacAddress '12:ab:12:ab:12:ab' -IP4Name 'TestCreate' -ObjectType MAKE_STATIC

This will create a Static Reservation for the next available IP Address in the 172.100.10.0 Network.



.Example
Mass Import with Offset:

    Create-ProteusIP4Object -UserName e12345a -Password [ENTER YOUR PASSWORD] -Subnet '172.100.10.0' -Offset '172.100.10.20' -CSVImport 'C:\temp\BAMImport.csv' -LogPath '\\someserver\share\BAMImport.log'

This will import all MAC addresses into BAM as designated in your Import CSV. IP Addresses will be assigned starting with 172.100.10.21 as available. Log file will be written to \\someserver\share.

.NOTES

CSV Format (No Headers)

00:00:00:12:00:ab,NameWithNoSpaces1,MAKE_STATIC
00:00:00:34:00:cd,NameWithNoSpaces2,MAKE_STATIC
00:00:00:56:00:ef,NameWithNoSpaces3,MAKE_DHCP_RESERVED
00:00:00:78:00:gh,NameWithNoSpaces4,MAKE_RESERVED
00:00:00:91:00:ij,NameWithNoSpaces5,MAKE_STATIC
00:00:00:12:00:kl,NameWithNoSpaces6,MAKE_STATIC


#>


param(

    [Parameter(Mandatory=$false,
        HelpMessage="Enter the Proteus API Url for your organization.")]
    [string]$ProteusAPIURL = "http://bam.ch.rmc/Services/API?wsdl",
    
    [Parameter(Mandatory=$true,
        HelpMessage="Enter the subnet of the desired IP4Network you would like to write to.")]
    [string]$Subnet,

    [Parameter(Mandatory=$false,
        HelpMessage="Enter offset, for example, if you do not want to start writing IP reservations until x.x.x.20 and higher.")]
    [string]$Offset,

    [Parameter(Mandatory=$false,
        HelpMessage="If you desire to mass import, enter the file path (Fully Qualified) to your import CSV.")]
    [string]$CSVImport = $null,

    [Parameter(Mandatory=$false,
        HelpMessage="If not importing, enter the mac address of the desired object.(Format xx:xx:xx:xx:xx:xx")]
    [string]$MacAddress = $null,

    [Parameter(Mandatory=$false,
        HelpMessage="Descriptive name for IP4Object.")]
    [string]$IP4Name = $null,

    [Parameter(Mandatory=$false,
        HelpMessage="Enter the desired IP4Object Type.")]
        [ValidateSet("MAKE_STATIC","MAKE_RESERVED","MAKE_DHCP_RESERVED")]
    [string]$ObjectType = $null,

    [Parameter(Mandatory=$false,
        HelpMessage="set `$true to run WhatIf.")]
    [bool]$WhatIf = $false,

    [Parameter(Mandatory=$false,
        HelpMessage="Change the log file Path.")]
    [string]$LogPath = "C:\Windows\Temp\BAMImport.log"

)

clear
clear
#Create connection to BAM API#########################

#$proteusdll = [System.Reflection.Assembly]::LoadFile('ProteusApi.dll') 
#$p1 = New-Object ProteusAPI
#$p1.url = $ProteusAPIURL
#$p1.login($UserName, $Password) | Out-Null



$credential = Get-Credential
$p1 = New-WebServiceProxy -Uri $ProteusAPIURL
$p1.CookieContainer = New-Object System.Net.CookieContainer
$p1.login($credential.UserName, ($credential.GetNetworkCredential()).Password)
$network = $p1.searchByObjectTypes("$Subnet", "IP4Network", 0, 999)

######################################################


function Create-IP4Object ($MacAddress,$IP4Name,$ObjectType)
{
    $ip = Get-NextAvailableIP
    $prop = "name=$IP4Name"
    $check = $p1.getIP4Address(5,$ip)
    if($check.id -eq 0)
    {
        if($WhatIf)
        {
            Write-LogLine "[WHATIF] Would assign $ip to $MacAddress as $IP4Name for $ObjectType. [ENDWHATIF]"
        }
        else
        {
            try
            {
                $p1.assignIP4Address(5,$ip,$MacAddress,$IP4Name,$ObjectType,$prop) | Out-Null
                $check = $p1.getIP4Address(5,$ip)
                if($check.id -eq 0)
                {
                    Write-LogLine "ERROR - This MAC ($MacAddress) already is assigned in this IP Space."
                }
                else
                {
                    Write-LogLine "SUCCESS - Successfully assigned $ip to $MacAddress as $IP4Name for $ObjectType."
                }
            }
            catch
            {
                Write-LogLine "ERROR - This MAC ($MacAddress) already is assigned in this IP Space."
            }
        }
    }        
}

function Get-NextAvailableIP
{
    if($Offset -eq $null)
    {
        return $p1.getNextIP4Address("$($network.id)",([regex]::Matches($($network.properties),"(?<=defaultView=)\d{6}").value))
    }
    else
    {
        return $p1.getNextIP4Address("$($network.id)","|offset=$Offset")
    }
}

function Write-LogLine ($message)
{
    if(!(Test-Path $LogPath))
    {
        New-Item -Path $LogPath -Force | Out-Null
    }
    $Content = $((Get-Date).ToString("MM-dd-yyyy hh:mm:ss")) + "   " + $message
    Add-Content -Path $LogPath -Value $Content
    $Content
}


#Do Work######################################

Write-LogLine "INFO - $UserName has accessed $ProteusAPIURL"

    try{
        [array]$Import = Get-Content -Path $CSVImport -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        foreach($imp in $Import)
        {
            $MacAddress = $imp.split(",")[0]
            $IP4Name = $imp.split(",")[1]
            $ObjectType = $imp.split(",")[2]

            Create-IP4Object -MacAddress $MacAddress -IP4Name $IP4Name -ObjectType $ObjectType
        }
    }
    catch{
        if($MacAddress -eq $null)
        {
            $MacAddress = Read-Host -Prompt "Enter a MAC Address (Format xx:xx:xx:xx:xx:xx)"
        }
        if($IP4Name -eq $null)
        {
            $IP4Name = Read-Host -Prompt "Enter a descriptive name"
        }
        if($ObjectType -eq $null)
        {
            $ObjectType = Read-Host -Prompt "Enter [MAKE_STATIC], [MAKE_RESERVED], or [MAKE_DHCP_RESERVED]"
        }
   
        Create-IP4Object -MacAddress $MacAddress -IP4Name $IP4Name -ObjectType $ObjectType
    }
$p1.logout() 