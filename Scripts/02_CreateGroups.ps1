<#
.SYNOPSIS
    Creates 6 security groups and adds department-based members
    Project 1 - Day 3
.DESCRIPTION
    Creates:
        - GG-Finance-Users
        - GG-IT-Users
        - GG-Sales-Users
        - GG-HR-Users
        - GG-Admins
        - GG-BreakGlass (empty - populated on Day 5)
    Then auto-assigns users to groups based on Department attribute.
.NOTES
    Run AFTER 01_BulkCreateUsers.ps1
#>

# ============================================================
# STEP 1 — CONNECT
# ============================================================
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All"

# ============================================================
# STEP 2 — DEFINE GROUPS
# ============================================================
$groups = @(
    @{ Name = "GG-Finance-Users"; Desc = "Finance department access group" }
    @{ Name = "GG-IT-Users";      Desc = "IT department access group" }
    @{ Name = "GG-Sales-Users";   Desc = "Sales department access group" }
    @{ Name = "GG-HR-Users";      Desc = "HR department access group" }
    @{ Name = "GG-Admins";        Desc = "Privileged admin group" }
    @{ Name = "GG-BreakGlass";    Desc = "Emergency break-glass account group" }
)

# ============================================================
# STEP 3 — CREATE GROUPS
# ============================================================
Write-Host ""
Write-Host "Creating security groups..." -ForegroundColor Cyan

foreach ($g in $groups) {
    try {
        $existing = Get-MgGroup -Filter "displayName eq '$($g.Name)'" -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "Already exists: $($g.Name)" -ForegroundColor Yellow
            continue
        }

        New-MgGroup `
            -DisplayName     $g.Name `
            -Description     $g.Desc `
            -MailEnabled:$false `
            -MailNickname    ($g.Name -replace "-", "") `
            -SecurityEnabled:$true | Out-Null

        Write-Host "Created group: $($g.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create $($g.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ============================================================
# STEP 4 — AUTO-ASSIGN USERS BASED ON DEPARTMENT
# ============================================================
Write-Host ""
Write-Host "Auto-assigning users to department groups..." -ForegroundColor Cyan

$deptToGroup = @{
    "Finance" = "GG-Finance-Users"
    "IT"      = "GG-IT-Users"
    "Sales"   = "GG-Sales-Users"
    "HR"      = "GG-HR-Users"
}

foreach ($dept in $deptToGroup.Keys) {
    $groupName = $deptToGroup[$dept]
    $group     = Get-MgGroup -Filter "displayName eq '$groupName'"
    $users     = Get-MgUser -Filter "department eq '$dept'" -All

    Write-Host ""
    Write-Host "Group: $groupName (Department = $dept)" -ForegroundColor Cyan

    foreach ($u in $users) {
        try {
            New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $u.Id
            Write-Host "  Added: $($u.DisplayName)" -ForegroundColor Green
        }
        catch {
            Write-Host "  Skipped (already member?): $($u.DisplayName)" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "GROUPS CREATED + MEMBERSHIP COMPLETE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "NOTE: GG-BreakGlass intentionally left empty"
Write-Host "      - it will be populated on Day 5"
