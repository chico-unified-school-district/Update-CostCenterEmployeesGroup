<#
.SYNOPSIS
Update membership of the Employee-Cost-Center group to keep licensing under 2500 users.
Scans users who are members of groups beginning with "CN=UN-*"
.DESCRIPTION
.EXAMPLE
.INPUTS
.OUTPUTS
.NOTES
#>
[cmdletbinding()]
param (
 [Parameter(Position = 0, Mandatory = $True)]
 [Alias('DCs')]
 [string[]]$DomainControllers,
 [Parameter(Position = 1, Mandatory = $True)]
 [System.Management.Automation.PSCredential]$ADCredential,
 [Parameter(Position = 3, Mandatory = $false)]
 [Alias('wi')]
 [SWITCH]$WhatIf
)
# Import Functions
. .\lib\Add-Log.ps1
. .\lib\Clear-SessionData.ps1
. .\lib\New-ADSession.ps1
. .\lib\Select-DomainController.ps1
. .\lib\Show-TestRun.ps1

Show-TestRun
Clear-SessionData

$dc = Select-DomainController $DomainControllers
$adCmdLets = 'Get-ADUser', 'Get-ADGroupMember', 'Add-ADGroupMember', 'Remove-ADGroupMember'
New-ADSession -dc $dc -cmdlets $adCmdLets -cred $ADCredential


$userOU = 'OU=Domain_Root,DC=chico,DC=usd'
# Filter out 'New Employee Accounts' OU and no UN-* group members
$userObjs = Get-ADUser -Filter * -SearchBase $userOU -Properties 'memberof' |
Where-Object { ($_.memberof -match "CN=UN-*") -and
 ($_.distinguishedName -notlike "*New Employee Accounts*") }

$group = 'Cost-Center-Employees'
$groupUsers = Get-ADGroupMember -Identity $group

$comparedObjects = Compare-Object -ReferenceObject $userObjs -DifferenceObject $groupUsers -Property SamAccountName

# Removes all stale members from Cost-Center-Employees
# Adds missing members to Cost-Center-Employees
foreach ($item in $comparedObjects) {
 if ($item.SideIndicator -eq "=>") {
  Add-Log remove ('{0},{1}' -f $group, $item.SamAccountName) $WhatIf
  Remove-ADGroupMember -Identity $group -Members $item.SamAccountName -Confirm:$false -WhatIf:$WhatIf
 }
 elseif ($item.SideIndicator -eq "<=") {
  Add-Log add ('{0},{1}' -f $group, $item.SamAccountName) $WhatIf
  Add-ADGroupMember -Identity $group -Members $item.SamAccountName -Confirm:$false -WhatIf:$WhatIf
 }
}
$groupMembers = Get-ADGroupMember -Identity $group
Add-Log total ('{0},{1} members' -f $group, $groupMembers.count) $WhatIf

Clear-SessionData
Show-TestRun