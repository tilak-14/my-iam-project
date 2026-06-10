<#
.SYNOPSIS
    Generates a comprehensive audit report of your tenant
    Project 1 - Day 9
.DESCRIPTION
    Exports:
        - All users and their attributes
        - All groups and members
        - All role assignments (privileged audit)
        - Recent sign-in events
        - Recent audit log changes
    Use this for the Security Verification Report.
.OUTPUT
    Creates CSV files in current folder.
#>

# ============================================================
# STEP 1 — CONNECT
# ============================================================
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All", "RoleManagement.Read.Directory", "AuditLog.Read.All", "Directory.Read.All"

$outputFolder = ".\AuditReports_$(Get-Date -Format 'yyyyMMdd_HHmm')"
New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
Write-Host "Output folder: $outputFolder" -ForegroundColor Green

# ============================================================
# REPORT 1 — ALL USERS
# ============================================================
Write-Host ""
Write-Host "Exporting users..." -ForegroundColor Cyan

Get-MgUser -All -Property DisplayName, UserPrincipalName, Department, Country, City, JobTitle, AccountEnabled, CreatedDateTime |
    Select-Object DisplayName, UserPrincipalName, Department, Country, City, JobTitle, AccountEnabled, CreatedDateTime |
    Export-Csv "$outputFolder\01_Users.csv" -NoTypeInformation

Write-Host "  Saved: 01_Users.csv" -ForegroundColor Green

# ============================================================
# REPORT 2 — ALL GROUPS + MEMBER COUNTS
# ============================================================
Write-Host ""
Write-Host "Exporting groups..." -ForegroundColor Cyan

$groupReport = @()
$allGroups = Get-MgGroup -All

foreach ($g in $allGroups) {
    $members = Get-MgGroupMember -GroupId $g.Id -All -ErrorAction SilentlyContinue
    $groupReport += [PSCustomObject]@{
        DisplayName     = $g.DisplayName
        Description     = $g.Description
        GroupType       = if ($g.GroupTypes -contains "DynamicMembership") { "Dynamic" } else { "Assigned" }
        MembershipRule  = $g.MembershipRule
        MemberCount     = $members.Count
        CreatedDateTime = $g.CreatedDateTime
    }
}

$groupReport | Export-Csv "$outputFolder\02_Groups.csv" -NoTypeInformation
Write-Host "  Saved: 02_Groups.csv" -ForegroundColor Green

# ============================================================
# REPORT 3 — PRIVILEGED ROLE ASSIGNMENTS (CRITICAL AUDIT)
# ============================================================
Write-Host ""
Write-Host "Exporting role assignments..." -ForegroundColor Cyan

$roleReport = @()
$assignments = Get-MgRoleManagementDirectoryRoleAssignment -All

foreach ($r in $assignments) {
    try {
        $principal = Get-MgDirectoryObject -DirectoryObjectId $r.PrincipalId -ErrorAction SilentlyContinue
        $role      = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $r.RoleDefinitionId

        $roleReport += [PSCustomObject]@{
            Principal     = $principal.AdditionalProperties.displayName
            PrincipalUPN  = $principal.AdditionalProperties.userPrincipalName
            Role          = $role.DisplayName
            Scope         = $r.DirectoryScopeId
            AssignmentId  = $r.Id
        }
    } catch {
        # Skip orphaned references
    }
}

$roleReport | Sort-Object Role, Principal | Export-Csv "$outputFolder\03_RoleAssignments.csv" -NoTypeInformation
Write-Host "  Saved: 03_RoleAssignments.csv" -ForegroundColor Green

# ============================================================
# REPORT 4 — RECENT SIGN-INS (LAST 24 HRS)
# ============================================================
Write-Host ""
Write-Host "Exporting recent sign-ins..." -ForegroundColor Cyan

$since = (Get-Date).AddHours(-24).ToString("yyyy-MM-ddTHH:mm:ssZ")
$signIns = Get-MgAuditLogSignIn -Filter "createdDateTime ge $since" -Top 500 -ErrorAction SilentlyContinue

$signIns | Select-Object CreatedDateTime, UserPrincipalName, AppDisplayName,
    @{N='IPAddress';E={$_.IPAddress}},
    @{N='Country';E={$_.Location.CountryOrRegion}},
    @{N='City';E={$_.Location.City}},
    @{N='Status';E={$_.Status.ErrorCode}},
    @{N='FailureReason';E={$_.Status.FailureReason}} |
    Export-Csv "$outputFolder\04_SignIns_Last24h.csv" -NoTypeInformation

Write-Host "  Saved: 04_SignIns_Last24h.csv ($($signIns.Count) entries)" -ForegroundColor Green

# ============================================================
# REPORT 5 — RECENT AUDIT EVENTS (LAST 24 HRS)
# ============================================================
Write-Host ""
Write-Host "Exporting audit events..." -ForegroundColor Cyan

$auditEvents = Get-MgAuditLogDirectoryAudit -Filter "activityDateTime ge $since" -Top 500 -ErrorAction SilentlyContinue

$auditEvents | Select-Object ActivityDateTime, ActivityDisplayName, Category, Result,
    @{N='Initiator';E={$_.InitiatedBy.User.UserPrincipalName}},
    @{N='TargetName';E={$_.TargetResources[0].DisplayName}},
    @{N='TargetType';E={$_.TargetResources[0].Type}} |
    Export-Csv "$outputFolder\05_AuditEvents_Last24h.csv" -NoTypeInformation

Write-Host "  Saved: 05_AuditEvents_Last24h.csv ($($auditEvents.Count) entries)" -ForegroundColor Green

# ============================================================
# REPORT 6 — CONDITIONAL ACCESS POLICY SUMMARY
# ============================================================
Write-Host ""
Write-Host "Exporting CA policies..." -ForegroundColor Cyan

$caPolicies = Get-MgIdentityConditionalAccessPolicy -All -ErrorAction SilentlyContinue

$caPolicies | Select-Object DisplayName, State, CreatedDateTime, ModifiedDateTime,
    @{N='IncludeUsers';E={$_.Conditions.Users.IncludeUsers -join ", "}},
    @{N='ExcludeGroups';E={$_.Conditions.Users.ExcludeGroups -join ", "}},
    @{N='IncludeApps';E={$_.Conditions.Applications.IncludeApplications -join ", "}},
    @{N='GrantControls';E={$_.GrantControls.BuiltInControls -join ", "}} |
    Export-Csv "$outputFolder\06_CAPolicies.csv" -NoTypeInformation

Write-Host "  Saved: 06_CAPolicies.csv ($($caPolicies.Count) policies)" -ForegroundColor Green

# ============================================================
# SUMMARY
# ============================================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "AUDIT REPORT GENERATION COMPLETE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Folder: $outputFolder"
Write-Host ""
Write-Host "Files generated:"
Get-ChildItem $outputFolder | Select-Object Name, Length | Format-Table -AutoSize
Write-Host ""
Write-Host "USE THIS DATA IN YOUR:"
Write-Host "  - Security Verification Report"
Write-Host "  - GitHub portfolio screenshots"
Write-Host "  - Interview demos"
