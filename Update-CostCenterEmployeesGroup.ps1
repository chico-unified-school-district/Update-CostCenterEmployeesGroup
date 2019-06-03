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
 [Alias('DC')]
 [ValidateScript( { Test-Connection -ComputerName $_ -Quiet -Count 1 })]
 [string]$DomainController,
 [Parameter(Position = 1, Mandatory = $True)]
 [Alias('ADCred')]
 [System.Management.Automation.PSCredential]$Credential,
 [Parameter(Position = 3, Mandatory = $false)]
 [SWITCH]$WhatIf
)

$adCmdLets = 'Get-ADUser', 'Get-ADGroupMember', 'Add-ADGroupMember', 'Remove-ADGroupMember'
$adSession = New-PSSession -ComputerName $DomainController -Credential $Credential
Import-PSSession -Session $adSession -Module ActiveDirectory -CommandName $adCmdLets -AllowClobber > $null

# Import Functions
. .\lib\Add-Log.ps1

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

Add-Log cleanup 'Tearing down sessions...'
Get-PSSession | Remove-PSSession -WhatIf:$WhatIf