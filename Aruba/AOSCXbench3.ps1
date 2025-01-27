# Load PowerArubaCX module
Import-Module PowerArubaCX

# Collect connection details interactively
$SwitchIP = Read-Host -Prompt "Enter the Switch IP address"
$OutputPath = Read-Host -Prompt "Path to output results to {.txt}"
Start-Transcript -Path $OutputPath
$SwitchIP


# Variables for the Switch Connection
#$SwitchIP = "192.168.1.100"        # Replace with your switch IP
#$Username = "admin"                # Replace with your switch username
$Password = "aruba123"             # Replace with your switch password
$CurrentLTSPatch = "TL.10.10.1140"    # Define the LTS version you’re checking against
[int]$DesiredTimeout = 60
#[string]$controlPlanevrf = "default"
[string]$controlPlanevrf = "mgmt"

# Connect to the Aruba Switch
$Session = Connect-ArubaCX $SwitchIP -SkipCertificateCheck
$API = Invoke-ArubaCXRestMethod -method "get" -uri "system" -selector configuration
$System = Get-ArubaCXSystem
$System.hostname



if ($Session) {
    Write-Host -ForegroundColor Cyan "Connected to the Aruba CX switch at $SwitchIP."
    
    # Check firmware version against LTS version
    $Firmware = Get-ArubaCXFirmware
    $CurrFirm = $Firmware.current_version
    if ($Firmware.current_version -ne $CurrentLTSPatch) {
        Write-Host -ForegroundColor Red "Warning: Switch firmware version ($CurrFirm) does not match the LTS version ($CurrentLTSPatch)."
    } else {
        Write-Host -ForegroundColor Green "Firmware is up-to-date with the LTS version."
    }

    # Check if sessions time out
    $CLITimeout = $API.cli_session.timeout
    [int]$CLITimeoutInt = $API.cli_session.timeout
    if ($CLITimeoutInt -le $DesiredTimeout) {
        Write-Host -ForegroundColor Green "CLI Session Timeout is acceptable. Current: $CLITimeout Desired: $DesiredTimeout"
    } else {
        Write-Host -ForegroungColor Red "CLI Session Timeout is not set or is set too high. Current: $CLITimeout Desired: $DesiredTimeout"
    }

    # Check if credentials are encrypted -- Actually checks length of password as returned by API.  HIGH LENGTH EQUALS LIKELY TO BE ENCRYPTED.
    $AdminUser = Get-ArubaCXUsers -User admin
    $AdminPassword = $AdminUser.password
    if ($AdminPassword.length -ge 40) {
        Write-Host -ForegroundColor Green "Credentials in configuration are likely encrypted. !This test is imperfect but AOS-CX default is 'encrypted'!"
    } else {
        Write-Host -ForegroungColor Red "Warning: Credentials in configuration may not be encrypted. Login with SSH and run 'show run' to verify. (This test is imperfect)"
    }

    # Check SSH cipher compliance
    $SSHCiphers = $API.ssh_ciphers
    $CompliantCiphers = [pscustomobject][Ordered]@{
        1='aes128-ctr'
        2='aes256-ctr'
        3='aes128-gcm@openssh.com'
        4='aes256-gcm@openssh.com'
    }


    for ( $ciphIndex = 1; $SSHCiphers.$ciphIndex; $ciphIndex++ )
    {
        $SSHCiphers.$ciphIndex
        $CompliantCiphers.$ciphIndex
        if ($SSHCiphers.$ciphIndex -eq $CompliantCiphers.$ciphIndex){

            Write-Host -ForegroundColor Green "Match"
        }else{Write-Host -ForegroundColor Red "No Match"
            $badCiphbool = $True

        }
    }




    if ($badCiphbool -eq $True) {
        Write-Host -ForegroundColor Red "Warning: Non-compliant SSH ciphers detected!"
        Write-Host -ForegroundColor Cyan "Desired Ciphers:"
        Write-Host $CompliantCiphers
        Write-Host -ForegroundColor Red "Current Switch SSH Ciphers:"
        Write-Host $SSHCiphers
        Write-Host -ForegroundColor Red "To remediate this issue, run 'ssh ciphers aes128-ctr aes256-ctr aes128-gcm@openssh.com aes256-gcm@openssh.com' in the configuration context on the switch [$SwitchIP]"
    } else {
        Write-Host -ForegroundColor Green "SSH ciphers are compliant with Terrapin Hardening."

    }
#>
    # Check for exec and MOTD banners
    $MotdBanner = $API.other_config.banner
    $ExecBanner = $API.other_config.banner_exec
    if ($MotdBanner -and $ExecBanner) {
        Write-Host -ForegroundColor Green "Exec and MOTD banners are configured."
    } else {
        Write-Host -ForegroundColor Red "Warning: Exec and/or MOTD banners are missing."
    }

    #Check Password Complexity Requirements
    $passwordComplexity = $API.password_complexity
    #$pwcEnable = $passwordComplexity.enable
    #$pwcEnable
    if ($passwordComplexity.enable -like "False") {
        Write-Host -ForegroundColor Red "Password Complexity Policy not Enabled"
    } elseif ($passwordComplexity.minimum_length -ge 8) {
        if (($passwordComplexity.lowercase_count -ge 1) -and ($passwordComplexity.numeric_count -ge 1) -and ($passwordComplexity.uppercase_count -ge 1) -and ($passwordComplexity.special_char_count -ge 1) ) {
            Write-Host -ForegroundColor Green "Password policy is compliant"
        } else {
            Write-Host -ForegroundColor Red "Review Password Complexity Policy"
        }
    } else {
        Write-Host -ForegroundColor Red "Review Password Complexity Policy (Enabled but not compliant$)"
    }

    #Verify Central Management Lockout
    $configLockout = $false
    $lockoutconfigcheck = $API.configuration_lockout_config
    if ($lockoutconfigcheck.central -eq "managed") {
        $configLockout = $true
        Write-Host -ForegroundColor Green "Device is Central Managed (in Config Lockout)"
    } else {
        Write-Host -ForegroundColor Red "Device is configurable (Not in Aruba Central Lockout...check status in Central)"
    }

    # Verify ACLs on admin access
    $AdminAccessACLs = Get-ArubaCXVrfs -name $controlPlanevrf -attributes aclv4_control_plane_applied
    if ($AdminAccessACLs.aclv4_control_plane_applied) {
        Write-Host -ForegroundColor Green "ACLs on admin access are applied."
    } else {
        Write-Host -ForegroundColor Red "Warning: No ACLs currently applied for admin access."
    }#

    # Disconnect from the Switch
    Disconnect-ArubaCX -Confirm:$false
    Write-Host -ForegroundColor Cyan "Disconnected from the switch."

} else {
    Write-Host -ForegroundColor Red "Failed to connect to the switch at $SwitchIP."
}
Stop-Transcript
