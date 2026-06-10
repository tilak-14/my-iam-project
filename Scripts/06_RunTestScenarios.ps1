<#
.SYNOPSIS
    Executes Day 9 test scenarios to validate IAM controls
    Project 1 - Day 9
.DESCRIPTION
    Runs automated tests:
        - Test 7: Group membership change (Karan)
        - Test 8: Dynamic group transfer (Lee)
        - Test 9: New user dynamic group placement
        - Test 10: Role assignment
    Generates audit trail for Security Verification Report.
.NOTES
    Tests 1-6 must be done manually (interactive sign-ins).
    This script handles tests 7-10 which are scriptable.
#>

$TenantDomain = "yourtenant.onmicrosoft.com"

# ============================================================
# CONNECT
# ============================================================
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "RoleManagement.ReadWrite.Directory"

# ============================================================
# TEST 7 — GROUP MEMBERSHIP CHANGE (AUDIT TRAIL)
# ============================================================
Write-Host ""
Write-Host "=== TEST 7: Group Membership Change ===" -ForegroundColor Cyan

$grp  = Get-MgGroup -Filter "displayName eq 'GG-Finance-Users'"
$user = Get-MgUser  -Filter "userPrincipalName eq 'karan.sales@$TenantDomain'"

if ($grp -and $user) {
    Write-Host "Adding Karan to GG-Finance-Users..." -ForegroundColor Yellow
    New-MgGroupMember -GroupId $grp.Id -DirectoryObjectId $user.Id
    Start-Sleep 30

    Write-Host "Removing Karan from GG-Finance-Users..." -ForegroundColor Yellow
    Remove-MgGroupMemberByRef -GroupId $grp.Id -DirectoryObjectId $user.Id

    Write-Host "Test 7 complete - verify in Audit Logs" -ForegroundColor Green
}

# ============================================================
# TEST 8 — DYNAMIC GROUP TRANSFER
# ============================================================
Write-Host ""
Write-Host "=== TEST 8: Dynamic Group Transfer (Lee) ===" -ForegroundColor Cyan

$lee = Get-MgUser -Filter "userPrincipalName eq 'lee.finance@$TenantDomain'"

if ($lee) {
    Write-Host "Moving Lee to Sales..." -ForegroundColor Yellow
    Update-MgUser -UserId $lee.Id -Department "Sales"
    Write-Host "Waiting 5 min for dynamic group evaluation..." -ForegroundColor Gray
    Start-Sleep 300

    $dg = Get-MgGroup -Filter "displayName eq 'DG-AllFinance-Users'"
    $members = Get-MgGroupMember -GroupId $dg.Id -All
    $stillThere = $members | Where-Object { $_.Id -eq $lee.Id }

    if ($stillThere) {
        Write-Host "WARNING: Lee still in Finance group - check rule" -ForegroundColor Red
    } else {
        Write-Host "PASS: Lee auto-removed from DG-AllFinance-Users" -ForegroundColor Green
    }

    Write-Host "Restoring Lee to Finance..." -ForegroundColor Yellow
    Update-MgUser -UserId $lee.Id -Department "Finance"

    Write-Host "Test 8 complete" -ForegroundColor Green
}

# ============================================================
# TEST 9 — NEW USER -> DYNAMIC GROUP
# ============================================================
Write-Host ""
Write-Host "=== TEST 9: New User Dynamic Group Placement ===" -ForegroundColor Cyan

$pwProfile = @{
    Password                      = "TempPass@2026!"
    ForceChangePasswordNextSignIn = $true
}

try {
    $testUser = New-MgUser `
        -DisplayName        "Test Temp User" `
        -UserPrincipalName  "test.temp@$TenantDomain" `
        -MailNickname       "testtemp" `
        -GivenName          "Test" `
        -Surname            "Temp" `
        -Department         "Finance" `
        -Country            "IN" `
        -UsageLocation      "IN" `
        -AccountEnabled:$true `
        -PasswordProfile    $pwProfile

    Write-Host "Created test user. Waiting 5 min for dynamic group eval..." -ForegroundColor Gray
    Start-Sleep 300

    $dgFin = Get-MgGroup -Filter "displayName eq 'DG-AllFinance-Users'"
    $dgInd = Get-MgGroup -Filter "displayName eq 'DG-India-Users'"

    $finMembers = Get-MgGroupMember -GroupId $dgFin.Id -All
    $indMembers = Get-MgGroupMember -GroupId $dgInd.Id -All

    $inFinance = $finMembers | Where-Object { $_.Id -eq $testUser.Id }
    $inIndia   = $indMembers | Where-Object { $_.Id -eq $testUser.Id }

    if ($inFinance) { Write-Host "PASS: Auto-added to DG-AllFinance-Users" -ForegroundColor Green }
    else            { Write-Host "FAIL: Not in DG-AllFinance-Users" -ForegroundColor Red }

    if ($inIndia)   { Write-Host "PASS: Auto-added to DG-India-Users" -ForegroundColor Green }
    else            { Write-Host "FAIL: Not in DG-India-Users" -ForegroundColor Red }

    Write-Host "Cleaning up test user..." -ForegroundColor Yellow
    Remove-MgUser -UserId $testUser.Id

    Write-Host "Test 9 complete" -ForegroundColor Green
}
catch {
    Write-Host "Test 9 failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================
# TEST 10 — ROLE ASSIGNMENT AUDIT
# ============================================================
Write-Host ""
Write-Host "=== TEST 10: Privileged Role Assignment ===" -ForegroundColor Cyan

$role = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq 'Helpdesk Administrator'"
$arun = Get-MgUser -Filter "userPrincipalName eq 'arun.it@$TenantDomain'"

if ($role -and $arun) {
    Write-Host "Assigning Helpdesk Admin to Arun..." -ForegroundColor Yellow

    $assignment = New-MgRoleManagementDirectoryRoleAssignment `
        -PrincipalId       $arun.Id `
        -RoleDefinitionId  $role.Id `
        -DirectoryScopeId  "/"

    Write-Host "Role assigned - verify in Audit Logs" -ForegroundColor Green
    Start-Sleep 10

    Write-Host "Removing Helpdesk Admin from Arun..." -ForegroundColor Yellow
    Remove-MgRoleManagementDirectoryRoleAssignment -UnifiedRoleAssignmentId $assignment.Id

    Write-Host "Test 10 complete" -ForegroundColor Green
}

# ============================================================
# DONE
# ============================================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ALL AUTOMATED TESTS COMPLETE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT STEPS:"
Write-Host "  1. Check Audit Logs for all generated events"
Write-Host "  2. Run 05_AuditScript.ps1 to export reports"
Write-Host "  3. Update Security Verification Report"
