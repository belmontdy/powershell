# powershell

My company has always struggled with creating DHCP Reservations and assigning Static IP's in Bluecat Address Manager (BAM).

This script solves that issue. It's pretty raw with very little error handling but works. If you are struggling with the same issue this will help or at least give you a place to start. I used the Proteus API (SOAP Calls) to write this script:

[Documentation](http://timlossev.com/attachments/Proteus_API_Guide_3.7.1.pdf)


[Link to Script](https://github.com/belmontdy/powershell/blob/master/Create-ProteusIP4Object.ps1)


Couple of things that I find that are poorly documented is What exactly the type of objects are that you deal with when using the Proteus API.


I struggled getting "offset" to work. Offset states where you want the API to start looking for IP Addresses. E.g. if your subnet is 172.100.10.0 the API will most likely see 172.100.10.2 as available. If you are like most businesses you may want to reserve the first 20 or so IP's for network gear.

In order to find "offset" is used the SOAP call. "getNextIP4Address()" This requires a Network ID and search string.
To find then network ID you first have to use "searchByObjectTypes()" to find your IP Space (IP4Network).

First create a login to the Proteus API.

`$credential = Get-Credential`
`$p1 = New-WebServiceProxy -Uri $ProteusAPIURL`
`$p1.CookieContainer = New-Object System.Net.CookieContainer`
`$p1.login($credential.UserName, ($credential.GetNetworkCredential()).Password)`

Then use this connection to Proteus API to search for the IP4Network Object. You'll need four components:

1. Subnet: IP address in a string format. e.g. "172.100.10.0"
2. Object Name: this is fixed, it should always be "IP4Network" for this use case.
3. Start/End Index: i wanted to search 0 through 999 records and if it hasn't found an IP4Network that matches my search it will error out, you can play with this if you have a large network, or make it smaller if you have a small one.

`$network = $p1.searchByObjectTypes("$Subnet", "IP4Network", 0, 999)`

Checking our Variable will return...

`$network | Format-List`
id         : **4314855**
name       : VLAN1055-NOTV-L3-WLAN-IPSK-TELEHEALTH-1
properties : [A Bunch of properties here]
type       : **IP4Network**

Returning the next available IP is simple.

To Return the next Available IP:
`$p1.getNextIP4Address("$($network.id)",$network.properties)`

To Return the next Available IP after the Offset:
`return $p1.getNextIP4Address("$($network.id)","|offset=$Offset")`

Assigning the IP will take a little work on your part. This will be your configuration ID.
Edit lines 117 and 118 of the script.

`$p1.assignIP4Address([INSERT YOUR CONFIGURATION ID HERE],$ip,$MacAddress,$IP4Name,$ObjectType,$prop) | Out-Null`
`$check = $p1.getIP4Address([INSERT YOUR CONFIGURATION ID HERE],$ip`)

You can get your configuration ID through the management portal:
1. Navigate to the Root of your IP Space (IP4)
2. Look in the address bar.
3. The last section of your URL will contain the ConfigurationID. Look for "Configuration%3A[ConfigurationID]" it will be the numbers immediately after the "Configuration%3A" in my case it is a single digit.

plug that in and you should be set to go.



[Link to Script](https://github.com/belmontdy/powershell/blob/master/Create-ProteusIP4Object.ps1)


