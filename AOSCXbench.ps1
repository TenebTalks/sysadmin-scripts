# Load PowerArubaCX module
Import-Module PowerArubaCX

# Collect connection details interactively
$SwitchIP = Read-Host -Prompt "Enter the Switch IP address"
Write-Host "You will receive a Credential Manager Prompt for the Switch Credentials"
#$Username = Read-Host -Prompt "Enter the Switch Username"
#$Password = Read-Host -Prompt "Enter the Switch Password" -AsSecureString | ConvertFrom-SecureString

# Variables for the Switch Connection
#$SwitchIP = "192.168.1.100"        # Replace with your switch IP
#$Username = "admin"                # Replace with your switch username
#$Password = "password"             # Replace with your switch password
$CurrentLTSPatch = "10.10.1140"    # Define the LTS version you’re checking against

# Connect to the Aruba Switch
#--ORIG $Session = Connect-ArubaCX -Hostname $SwitchIP -Username $Username -Password $Password
$Session = Connect-ArubaCX $SwitchIP -SkipCertificateCheck

if ($Session) {
    Write-Output "Connected to the Aruba CX switch at $SwitchIP."
    
    # Check firmware version against LTS version
    $Firmware = Get-ArubaCXFirmware
    if ($Firmware.current_version -ne $CurrentLTSPatch) {
        Write-Output "Warning: Switch firmware version ($($Firmware.SoftwareVersion)) does not match the LTS version ($CurrentLTSPatch)."
    } else {
        Write-Output "Firmware is up-to-date with the LTS version."
    }

    # Check if credentials are encrypted
    $Config = Get-ArubaCXConfiguration -Session $Session
    if ($Config.Config | Select-String -Pattern "encrypted") {
        Write-Output "Credentials in configuration are encrypted."
    } else {
        Write-Output "Warning: Credentials in configuration may not be encrypted."
    }

    # Check SSH cipher compliance
    $SSHSettings = Get-ArubaCXSSHSettings -Session $Session
    $CompliantCiphers = @("aes128-ctr", "aes256-ctr", "aes128-gcm", "aes256-gcm")
    $NonCompliantCiphers = $SSHSettings.Ciphers | Where-Object { $_ -notin $CompliantCiphers }
    if ($NonCompliantCiphers) {
        Write-Output "Warning: Non-compliant SSH ciphers detected: $NonCompliantCiphers"
    } else {
        Write-Output "SSH ciphers are compliant with Terrapin Hardening."
    }

    # Check for exec and MOTD banners
    $Banner = Get-ArubaCXBanner -Session $Session
    if ($Banner.Exec -and $Banner.MOTD) {
        Write-Output "Exec and MOTD banners are configured."
    } else {
        Write-Output "Warning: Exec and/or MOTD banners are missing."
    }

    # Verify console timeout is 1 hour or less
    $ConsoleSettings = Get-ArubaCXConsoleSettings -Session $Session
    if ($ConsoleSettings.Timeout -le 60) {
        Write-Output "Console timeout is set correctly."
    } else {
        Write-Output "Warning: Console timeout exceeds 1 hour."
    }

    # Verify ACLs on admin access
    $AdminAccessACLs = Get-ArubaCXACL -Session $Session | Where-Object { $_.Type -eq "admin-access" }
    if ($AdminAccessACLs) {
        Write-Output "ACLs on admin access are configured."
    } else {
        Write-Output "Warning: No ACLs configured for admin access."
    }

    # Disconnect from the Switch
    Disconnect-ArubaCX -Confirm:$false
    Write-Output "Disconnected from the switch."

} else {
    Write-Output "Failed to connect to the switch at $SwitchIP."
}
