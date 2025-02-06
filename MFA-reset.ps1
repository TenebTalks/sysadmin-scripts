#Create a variable with a blank MFAconfig:
$noMfaConfig = @()
#Print the instructions to the screen:
Write-Host "README: You will be prompted for the user's full username, which is their email address.  Next, you will get a full modern authentication window.   You must sign into it as a Microsoft365 admin account - either a dedicated Office Admin or one of the Domain admins depending on the environment.  After signing in, The user's current StrongAuthenticationMethods property will be displayed, followed by a prompt confirming whether you want to clear that user's StrongAuthenticationMethods.  After you've made your choice, the system will print the StrongAuthenticationMethods again, either cleared or the same as before."
Write-Host ""
#Get user object to reset from Technician
$Upn = Read-Host -Prompt 'Input full username, eg username@entratenant.biz, ADuser@adsyncenvironment.net, etc.'

#This command connects to the Microsoft Online Service, thus prompting for an O365 login.  It will accept an Office365 login from any client, most likely.  User must only put a WMP admin in to the modern auth box.
Connect-MsolService

#Print the current MFA status, in a summary form, to the terminal.
Write-Host "Current MFA for this user:"
$UserObject = Get-MsolUser -UserPrincipalName $Upn
$AuthMethods = $UserObject.StrongAuthenticationMethods
Write-Host $AuthMethods

Start-Sleep -Seconds 1

#Prompt technician for confirmation that we want to clear this user's MFA.
$Upn
$ClearMFA = Read-Host -Prompt 'Clear this user`s Microsoft Authenticator MFA? (Y/N)'

#If the tech says "Y", then clear the MFA, else...don't.
if( $ClearMFA -eq "Y")
{
    Set-MsolUser -UserPrincipalName $Upn -StrongAuthenticationMethods $noMfaConfig
} else{
    Write-Host "User information was not altered."
}

#Show the MFA summary again, hopefully it is clear if you hit Y and not clear if you hit N
Write-Host ""
Write-Host "Now it is:"
$UserObject = Get-MsolUser -UserPrincipalName $Upn
$AuthMethods = $UserObject.StrongAuthenticationMethods
Write-Host $AuthMethods

#v1.0  written by Scott Bennett, sbennett@teamascend.com
#version notes:
#v1.0 - Added notes and altered confirmation prompt.  It seems admin accounts (i.e. ad_jdoe@westmonroepartners.com) have a permission level that the west monroe service desk admins cannot reset.
#v0.4a Currently can't get the StrongAuthenticationMethods to print out nicely from the script.
#If you run $UserObject.StrongAuthenticationMethods in the script, it waits to print them out after the script stops.
#What I can currently do is print out "Microsoft.Online.Administration.StrongAuthenticationMethod" for each number of time there is one, (most phones show up as two of these, one for push and one for 6-digit MFA)
#I think this is adequate, tbh, but I really wanted the nice printout you get from pulling that variable object in the cli
#
#v0.5 - de-WMPification - this script can be used for any client with MS Authenticator based MFA.