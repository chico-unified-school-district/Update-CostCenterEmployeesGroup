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
   Where-Object { ($_.MemberOf -match 'CN=UN-*') -and
    ($_.distinguishedName -notlike '*New Employee Accounts*') }
 }
}

function Update-GroupMembership ($group, [PSCredential]$cred) {
 process {
  if ($_.SideIndicator -eq '=>') {
   Remove-ADGroupMember -Identity $group -Members $_.SamAccountName -Credential $cred -Confirm:$false -WhatIf:$WhatIf
   return (Write-Host ('{0},Remove,{1},{2}' -f $MyInvocation.MyCommand.Name, $group, $_.SamAccountName) -F DarkYellow)
  }
  Add-ADGroupMember -Identity $group -Members $_.SamAccountName -Credential $cred -Confirm:$false -WhatIf:$WhatIf
  Write-Host ('{0},Add,{1},{2}' -f $MyInvocation.MyCommand.Name, $group, $_.SamAccountName) -f Blue
 }
}

# ================================= main ==================================
Show-BlockInfo start

Import-Module -Name CommonScriptFunctions -Cmdlet Show-BlockInfo, Show-TestRun
$adCmdlets = 'Get-ADUser', 'Get-ADGroupMember', 'Add-ADGroupMember', 'Remove-ADGroupMember'
Import-Module -Name ActiveDirectory -Cmdlet $adCmdlets -WarningAction SilentlyContinue -ErrorAction Stop

Show-BlockInfo main

if ($WhatIf) { Show-TestRun }

$group = 'Cost-Center-Employees'
$groupUsers = Get-ADGroupMember -Identity $group -Credential $ADCredential
$eligibleUsers = Get-EligibleUsers -ou $OrgUnit -cred $ADCredential
Compare-Object -ReferenceObject $eligibleUsers -DifferenceObject $groupUsers -Property SamAccountName |
 Update-GroupMembership -group $group -cred $ADCredential

if ($WhatIf) { Show-TestRun }
Show-BlockInfo end