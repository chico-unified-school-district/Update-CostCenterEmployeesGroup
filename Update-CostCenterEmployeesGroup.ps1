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
 [Parameter(Mandatory = $True)][PSCredential]$ADCredential,
 [Parameter(Mandatory = $False)][string]$OrgUnit,
 [Alias('wi')][SWITCH]$WhatIf
)

if ($WhatIf) { Show-TestRun }

Import-Module -Name CommonScriptFunctions
$adCmdlets = 'Get-ADUser', 'Get-ADGroupMember', 'Add-ADGroupMember', 'Remove-ADGroupMember'
Import-Module -Name ActiveDirectory -Cmdlet $adCmdlets -WarningAction SilentlyContinue -ErrorAction Stop

# Filter out 'New Employee Accounts' OU and no UN-* group members
$userObjs = Get-ADUser -Filter * -SearchBase $OrgUnit -Properties 'memberof' -Credential $ADCredential |
 Where-Object { ($_.memberof -match 'CN=UN-*') -and
  ($_.distinguishedName -notlike '*New Employee Accounts*') }

$group = 'Cost-Center-Employees'
$groupUsers = Get-ADGroupMember -Identity $group -Credential $ADCredential

$comparedObjects = Compare-Object -ReferenceObject $userObjs -DifferenceObject $groupUsers -Property SamAccountName

# Removes all stale members from Cost-Center-Employees
# Adds missing members to Cost-Center-Employees
$logPrefix = if ($WhatIf) { '[WhatIf] ' } else { '' }
foreach ($item in $comparedObjects) {
 if ($item.SideIndicator -eq '=>') {
  Write-Host ('{0}{1}: remove,{2},{3}' -f $logPrefix, $MyInvocation.MyCommand.Name, $group, $item.SamAccountName)
  Remove-ADGroupMember -Identity $group -Members $item.SamAccountName -Credential $ADCredential -Confirm:$false -WhatIf:$WhatIf
 }
 elseif ($item.SideIndicator -eq '<=') {
  Write-Host ('{0}{1}: add,{2},{3}' -f $logPrefix, $MyInvocation.MyCommand.Name, $group, $item.SamAccountName)
  Add-ADGroupMember -Identity $group -Members $item.SamAccountName -Credential $ADCredential -Confirm:$false -WhatIf:$WhatIf
 }
}
$groupMembers = Get-ADGroupMember -Identity $group -Credential $ADCredential
Write-Host ('{0}{1}: total,{2},{3} members' -f $logPrefix, $MyInvocation.MyCommand.Name, $group, $groupMembers.count)

if ($WhatIf) { Show-TestRun }