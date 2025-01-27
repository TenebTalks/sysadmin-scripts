Write-Host "A white O365 modern authentication box will have popped up. Enter an admin account credentials to the domain you're working in.  It needs to have O365 access."
Connect-ExchangeOnline  #uncomment when ready.  Commented to test prompts
#Edit this here for the list of calendars that need ADDED permission. Quotations are needed
$CalendarList = Read-Host -Prompt 'Input User who OWNs the calendar.'

#Edit this here for the list of users that are to RECEIVE permissions. Quotations are needed
$PermissionList = Read-Host -Prompt 'Input User to RECEIVE permission' #"useremail1@xxx.com","useremail2@xxx.com", etc
$AccRights = Read-Host -Prompt 'Enter the exact -AccessRights entry you wish to set these permissions to.  PublishingEditor Editor Reviewer etc.  For full list look up Set-MailboxFolderPermissions on Microsoft website.'
<#
OR
If you have a very long list and would prefer to import a csv file
#>
$CalendarList = Import-CSV -Path ".\CalendarList.txt"
$PermissionList = Import-CSV -Path ".\UserList.txt"




#Foreach calendar in the list -> grant each user this level of access
ForEach ($Calendar in $CalendarList){
	Write-Host $Calendar+";"
	ForEach($User in $PermissionList){
        Write-Host $User
		#MAKE SURE YOU EDIT THE LEVEL OF ACCESS NEEDED. REVIEWER IS HERE BY DEFAULT.
		Add-MailboxFolderPermission -Identity ${Calendar}:\calendar -user $User -AccessRights $AccRights
	}
}