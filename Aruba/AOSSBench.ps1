# Load PowerArubaSW module
Import-Module PowerArubaSW

# Collect connection details interactively
$SwitchIP = Read-Host -Prompt "Enter the Switch IP address"
$Username = Read-Host -Prompt "Enter the Switch Username"
$Password = Read-Host -Prompt "Enter the Switch Password" -AsSecureString

# Define the LTS version to check against
$CurrentLTSPatch = "16.10.0010"    # Modify if LTS version changes

# Connect to the Aruba Switch
$Session = Connect-ArubaSW -Hostname $SwitchIP -Username $Username -Password $Password

if ($Session) {
    Write-Output "Connected to the Aruba AOS-S switch at $SwitchIP."
    
    # Check firmware version against LTS version
    $Firmware = Get-ArubaSWFirmwareVersion -Session $Session
    if ($Firmware.SoftwareVersion -ne $CurrentLTSPatch) {
        Write-Output "Warning: Switch firmware version ($($Firmware.SoftwareVersion)) does not match the LTS version ($CurrentLTSPatch)."
    } else {
        Write-Output "Firmware is up-to-date with the LTS version."
    }

    # Check if credentials are encrypted
    $Config = Get-ArubaSWConfiguration -Session $Session
    if ($Config.Config | Select-String -Pattern "encrypted") {
        Write-Output "Credentials in configuration are encrypted."
    } else {
        Write-Output "Warning: Credentials in configuration may not be encrypted."
    }

    # Check SSH cipher compliance
    $SSHSettings = Get-ArubaSWSSHSettings -Session $Session
    $CompliantCiphers = @("aes128-ctr", "aes256-ctr", "aes128-gcm", "aes256-gcm")
    $NonCompliantCiphers = $SSHSettings.Ciphers | Where-Object { $_ -notin $CompliantCiphers }
    if ($NonCompliantCiphers) {
        Write-Output "Warning: Non-compliant SSH ciphers detected: $NonCompliantCiphers"
    } else {
        Write-Output "SSH ciphers are compliant with Terrapin Hardening."
    }

    # Check for exec and MOTD banners
    $Banner = Get-ArubaSWBanner -Session $Session
    if ($Banner.Exec -and $Banner.MOTD) {
        Write-Output "Exec and MOTD banners are configured."
    } else {
        Write-Output "Warning: Exec and/or MOTD banners are missing."
    }

    # Verify console timeout is 1 hour or less
    $ConsoleSettings = Get-ArubaSWConsoleSettings -Session $Session
    if ($ConsoleSettings.Timeout -le 60) {
        Write-Output "Console timeout is set correctly."
    } else {
        Write-Output "Warning: Console timeout exceeds 1 hour."
    }

    # Verify ACLs on admin access
    $AdminAccessACLs = Get-ArubaSWACL -Session $Session | Where-Object { $_.Type -eq "admin-access" }
    if ($AdminAccessACLs) {
        Write-Output "ACLs on admin access are configured."
    } else {
        Write-Output "Warning: No ACLs configured for admin access."
    }

    # Disconnect from the Switch
    Disconnect-ArubaSW -Session $Session
    Write-Output "Disconnected from the switch."

} else {
    Write-Output "Failed to connect to the switch at $SwitchIP."
}
