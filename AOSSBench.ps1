#Check for PowerArubaSW Module
$mod = Get-Command -Module PowerArubaSW
Write-Output "MOD:"
$mod

if ($mod -notcontains "Function") {
    Install-Module PowerArubaSW
}
  

# Load PowerArubaSW module
Import-Module PowerArubaSW

# Collect connection details interactively
[string]$SwitchIP = Read-Host -Prompt "Enter the Switch IP address"
#$Username = Read-Host -Prompt "Enter the Switch Username"
#$Password = Read-Host -Prompt "Enter the Switch Password" -AsSecureString

# Define the LTS version to check against
##- $CurrentLTSPatch = "WC.16.10.0010"    # Modify if LTS version changes
$CurrentLTSPatch = "WC.16.10.0012"
# Desired Console Timeout Maximum
[int]$DesiredCT = 3600

# Connect to the Aruba Switch
$Session = Connect-ArubaSW -Server $SwitchIP -SkipCertificateCheck
#Connect-ArubaSW -Hostname $SwitchIP -SkipCertificateCheck




if ($Session) {
    Write-Output "Connected to the Aruba AOS-S switch at $SwitchIP."
    
    # Check firmware version against LTS version
    $SystemStatus = Get-ArubaSWSystemStatus
    $Firmware = $SystemStatus.firmware_version
    if ($Firmware -ne $CurrentLTSPatch) {
        Write-Output "Warning: Switch firmware version ($($Firmware)) does not match the LTS version ($CurrentLTSPatch)."
    } else {
        Write-Output "Firmware is up-to-date with the LTS version."
    }

    # Check if credentials are encrypted
    $Config = Get-ArubaSWCli -cmd "show run"
    if ($Config.result.Contains("encrypt-credentials")){
        Write-Output "Credentials in configuration are encrypted."
    } else {
        Write-Output "Warning: Credentials in configuration may not be encrypted."
    }

    # Check SSH cipher compliance
    $SSHSettings = Get-ArubaSWCli -cmd 'show ip ssh'
    $SSHstring = $SSHSettings.result
    $ciphs = $SSHstring.IndexOf("Ciphers")
    $ciphs = ($ciphs + 9)
    $MACs = $SSHstring.IndexOf("MACs")
    $ciphLength = ($MACs - $ciphs)
    #$ciphLength #debug
    $CipherString = $SSHstring.Substring($ciphs, $ciphLength)
    $CipherString = $CipherString.replace(" ","")
    $CipherString = $CipherString.replace("`n","")
    $Cipherray = ConvertFrom-String -InputObject $CipherString -Delimiter ","
    #$CipherString #debug
    #$Cipherray #debug
    $CompliantCiphers = @("aes128-ctr", "aes256-ctr", "aes128-gcm", "aes256-gcm")
    $NonCompliantCiphers = ($Cipherray.PSObject.Properties | ForEach-Object { $_.Value }) | Where-Object { $_ -notin $CompliantCiphers }
    if ($NonCompliantCiphers) {
        Write-Output "Warning: Non-compliant SSH ciphers detected: $NonCompliantCiphers"
    } else {
        Write-Output "SSH ciphers are compliant with Terrapin Hardening."
    }

    # Check for exec and MOTD banners
    $Banner = Get-ArubaSWBanner
    if ($Banner.Exec -and $Banner.MOTD) {
        Write-Output "Exec and MOTD banners are configured."
    } else {
        Write-Output "Warning: Exec and/or MOTD banners are missing."
    }

    # Verify console timeout is 1 hour or less
    $ConsoleTimeoutGet = Get-ArubaSWCli -cmd 'show run | in idle-timeout | ex serial'
    if($ConsoleTimeoutGet.result){
        [string]$CTstring = $ConsoleTimeoutGet.result
        $CTnumstr = $CTstring.Substring(21, 4)
        $CTint = [int]$CTnumstr
        if ($CTint -le $DesiredCT) {
            Write-Output "Console timeout is acceptable."
            $CTstring
        } else {
            Write-Output "Warning: Console timeout exceeds $DesiredCT seconds"
        }
    } else {
        Write-Output "Console timeout may not be set. Verify Manually"
        $ConsoleTimeoutGet
    }
    
    # Verify ACLs on admin access
    $AuthMgr = Get-ArubaSWCli -cmd "show run | in authorized-managers"
    if ($Config.result.Contains('authorized-managers')) {
        Write-Output "ACLs on admin access are configured."
        $AuthMgr.result
    } else {
        Write-Output "Warning: No ACLs configured for admin access."
    }

    #Verify DNS is configured on Switch
    $DNSconfig = Get-ArubaSWDns
    if ($DNSconfig.dns_config_mode -eq "DCM_MANUAL"){
        Write-Output "DNS is configured with the following servers:"
        $DNSconfig.server_1.octets
        $DNSconfig.server_2.octets
    } else {
        Write-Output "DNS Not manually configured"
    }

    #Verify STP settings
    $STPconfig = Get-ArubaSWSTP
    if ($STPconfig.is_enabled -eq $True) {
        Write-Output "STP is enabled and in mode:"
        $STPconfig.mode
    }else {
        Write-Output "STP is Disabled"
    }

    #Verify Telnet is disabled
    if ($Config.result.Contains('no telnet-server')) {
        Write-Output "Telnet is Disabled"
    } else {
        Write-Output "TELNET IS ENABLED"
    }

    #Verify SNMP Settings
    $SNMPiwr = Invoke-ArubaSWWebRequest -uri "snmp-server"
    [string]$SNMPstring = $SNMPiwr.Content
    if ($SNMPstring.Contains('"is_snmp_server_enabled":true')) {
        Write-Output "SNMP Server is enabled"
        
        $SNMPwritecomm = Get-ArubaSWCli -cmd 'show snmp-server | in Unrestricted'
        if($SNMPwritecomm.result){
            Write-Output "Communities with Write Access:"
            $SNMPwritecomm.result
        } else {
            Write-Output "No Communities with Write Access"
        }

    } else {
        Write-Output "SNMP Server is disabled."
    }

    # Disconnect from the Switch
    Disconnect-ArubaSW -Confirm:$false
    Write-Output "Disconnected from the switch."

} else {
    Write-Output "Failed to connect to the switch at $SwitchIP."
}
