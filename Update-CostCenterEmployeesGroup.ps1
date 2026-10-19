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
 [Alias('wi')][switch]$WhatIf
)

function Get-EligibleUsers ($ou, [PSCredential]$cred) {
 process {
  Get-ADUser -Filter * -SearchBase $ou -Properties 'memberof' -Credential $cred |
   Where-Object { ($_.memberof -match 'CN=UN-*') -and
    ($_.distinguishedName -notlike '*New Employee Accounts*') }
 }
}

function Update-GroupMembership ([PSCredential]$cred) {
 process {
  $action = if ($_.SideIndicator -eq '=>') { 'remove' } else { 'add' }
  $logPrefix = if ($WhatIf) { '[WhatIf] ' } else { '' }
  $msgVars = $logPrefix, $MyInvocation.MyCommand.Name, $action, $group, $_.SamAccountName
  Write-Host ('{0}{1},{2},{3},{4}' -f $msgVars) -Fore Blue

  if ($_.SideIndicator -eq '=>') {
   Remove-ADGroupMember -Identity $group -Members $_.SamAccountName -Credential $cred -Confirm:$false -WhatIf:$WhatIf
  }
  else {
   Add-ADGroupMember -Identity $group -Members $_.SamAccountName -Credential $cred -Confirm:$false -WhatIf:$WhatIf
  }
 }
}

function Show-GroupMemberTotal ([PSCredential]$cred) {
 $groupMembers = Get-ADGroupMember -Identity $group -Credential $cred
 $logPrefix = if ($WhatIf) { '[WhatIf] ' } else { '' }
 $msgVars = $logPrefix, $MyInvocation.MyCommand.Name, $group, $groupMembers.count
 Write-Host ('{0}{1},{2},{3} members' -f $msgVars) -Fore Blue
}

# ================================= main ==================================
Import-Module -Name CommonScriptFunctions -Cmdlet Show-BlockInfo, Show-TestRun
$adCmdlets = 'Get-ADUser', 'Get-ADGroupMember', 'Add-ADGroupMember', 'Remove-ADGroupMember'
Import-Module -Name ActiveDirectory -Cmdlet $adCmdlets -WarningAction SilentlyContinue -ErrorAction Stop
Show-BlockInfo main

if ($WhatIf) { Show-TestRun }
$group = 'Cost-Center-Employees'
$groupUsers = Get-ADGroupMember -Identity $group -Credential $ADCredential
Get-EligibleUsers -ou $OrgUnit -cred $ADCredential |
 Compare-Object -DifferenceObject $groupUsers -Property SamAccountName |
  Update-GroupMembership -cred $ADCredential
Show-GroupMemberTotal -cred $ADCredential

if ($WhatIf) { Show-TestRun }
Show-BlockInfo end