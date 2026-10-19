# Update-CostCenterEmployeesGroup

Reconciles membership of the Active Directory `Cost-Center-Employees` group with eligible users in a specified organizational unit.

## Requirements

- Windows PowerShell with the Active Directory module available (RSAT or a domain management host).
- The `CommonScriptFunctions` module, which provides the `Show-BlockInfo` and `Show-TestRun` commands.
- An account with permission to read users and group membership and to update the target group.

## Eligibility

The script searches for users under the supplied `OrgUnit` and selects accounts whose `memberOf` attribute matches `CN=UN-*`. It excludes users whose distinguished name contains `New Employee Accounts`.

The current implementation uses PowerShell's regex `-match` operator for `CN=UN-*`; this is not a wildcard prefix pattern. Verify that this expression matches the intended source groups before running the script.

Eligible users missing from `Cost-Center-Employees` are added, and current group members who are not eligible are removed. The script does not create the target group.

## Usage

```powershell
$credential = Get-Credential

.\Update-CostCenterEmployeesGroup.ps1 `
	-ADCredential $credential `
	-OrgUnit 'OU=Root,DC=company,DC=org' `
	-WhatIf
```

`-ADCredential` is required. `-OrgUnit` is optional; specify it to limit the user search to an OU. `-WhatIf` previews the group membership changes without applying them. Remove `-WhatIf` to make the changes.

## Output

The script writes a line for each proposed or applied change, identifying the operation (`Add` or `Remove`), target group, and user SamAccountName. In `-WhatIf` mode, these lines describe the attempted changes; the Active Directory cmdlets do not apply them.
