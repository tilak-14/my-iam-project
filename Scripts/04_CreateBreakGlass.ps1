<#
.SYNOPSIS
    Creates 2 break-glass emergency admin accounts following Microsoft official pattern
    Project 1 - Day 5
.DESCRIPTION
    Creates:
        - 2 cloud-only accounts with 48-char random passwords
        - Assigns Global Administrator role permanently
        - Adds both to GG-BreakGlass group (for CA policy exclusion)
.SECURITY
    CRITICAL: After running this script:
        1. Copy the generated passwords to physical paper
        2. Seal in 2 separate envelopes
        3. Store in physical safe (offline)
        4. Clear PowerShell history: Clear-History
        5. NEVER store passwords in email/Teams/cloud notes
.NOTES
    Replace "yourtenant.onmicrosoft.com" with your actual tenant domain
#>

# IMPORTANT: Replace with your tenant domain
$TenantDomain = "yourtenant.onmicrosoft.com"

# ============================================================
# STEP 1 — CONNECT
# ============================================================
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.ReadWrite.All", "RoleManagement.ReadWrite.Directory", "Group.ReadWrite.All"

# ============================================================
# STEP 2 — PASSWORD GENERATOR
# ============================================================
function New-BreakGlassPassword {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*'
    -join ((1..48) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

$BG1_Password = New-BreakGlassPassword
$BG2_Password = New-BreakGlassPassword

# ============================================================
# STEP 3 — CREATE ACCOUNT 1
# ============================================================
$pwProfile1 = @{
    Password                      = $BG1_Password
    ForceChangePasswordNextSignIn = $false
}

try {
    New-MgUser `
        -DisplayName        "Emergency Access Account 1" `
        -UserPrincipalName  "breakglass1@$TenantDomain" `
        -MailNickname       "breakglass1" `
        -GivenName          "Emergency" `
        -Surname            "Access1" `
        -JobTitle           "Break-Glass Account" `
        -Department         "Emergency Access" `
        -UsageLocation      "IN" `
        -AccountEnabled:$true `
        -PasswordProfile    $pwProfile1 | Out-Null

    Write-Host "Created: breakglass1" -ForegroundColor Green
}
catch {
    Write-Host "Failed breakglass1: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================
# STEP 4 — CREATE ACCOUNT 2
# ============================================================
$pwProfile2 = @{
    Password                      = $BG2_Password
    ForceChangePasswordNextSignIn = $false
}

try {
    New-MgUser `
        -DisplayName        "Emergency Access Account 2" `
        -UserPrincipalName  "breakglass2@$TenantDomain" `
        -MailNickname       "breakglass2" `
        -GivenName          "Emergency" `
        -Surname            "Access2" `
        -JobTitle           "Break-Glass Account" `
        -Department         "Emergency Access" `
        -UsageLocation      "IN" `
        -AccountEnabled:$true `
        -PasswordProfile    $pwProfile2 | Out-Null

    Write-Host "Created: breakglass2" -ForegroundColor Green
}
catch {
    Write-Host "Failed breakglass2: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================
# STEP 5 — ASSIGN GLOBAL ADMIN ROLE
# ============================================================
Write-Host ""
Write-Host "Assigning Global Administrator role..." -ForegroundColor Cyan

$role = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq 'Global Administrator'"
$bg1  = Get-MgUser -Filter "userPrincipalName eq 'breakglass1@$TenantDomain'"
$bg2  = Get-MgUser -Filter "userPrincipalName eq 'breakglass2@$TenantDomain'"

foreach ($bg in @($bg1, $bg2)) {
    try {
        New-MgRoleManagementDirectoryRoleAssignment `
            -PrincipalId       $bg.Id `
            -RoleDefinitionId  $role.Id `
            -DirectoryScopeId  "/" | Out-Null

        Write-Host "Global Admin assigned to: $($bg.DisplayName)" -ForegroundColor Green
    }
    catch {
        Write-Host "Role assignment failed for $($bg.DisplayName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ============================================================
# STEP 6 — ADD TO GG-BreakGlass GROUP
# ============================================================
Write-Host ""
Write-Host "Adding to GG-BreakGlass group..." -ForegroundColor Cyan

$group = Get-MgGroup -Filter "displayName eq 'GG-BreakGlass'"

if ($group) {
    try {
        New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $bg1.Id
        New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $bg2.Id
        Write-Host "Both accounts added to GG-BreakGlass" -ForegroundColor Green
    }
    catch {
        Write-Host "Group membership add failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
else {
    Write-Host "GG-BreakGlass group not found - run Script 02 first" -ForegroundColor Red
}

# ============================================================
# STEP 7 — DISPLAY PASSWORDS (CRITICAL — STORE OFFLINE NOW)
# ============================================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor Red
Write-Host "CRITICAL: STORE PASSWORDS OFFLINE NOW" -ForegroundColor Red
Write-Host "==========================================" -ForegroundColor Red
Write-Host ""
Write-Host "breakglass1@$TenantDomain"
Write-Host "Password: $BG1_Password" -ForegroundColor Yellow
Write-Host ""
Write-Host "breakglass2@$TenantDomain"
Write-Host "Password: $BG2_Password" -ForegroundColor Yellow
Write-Host ""
Write-Host "==========================================" -ForegroundColor Red
Write-Host "ACTIONS REQUIRED:" -ForegroundColor Red
Write-Host "  1. Write passwords on paper"
Write-Host "  2. Seal in separate envelopes"
Write-Host "  3. Store in physical safe (offline)"
Write-Host "  4. Run: Clear-History"
Write-Host "  5. Close PowerShell window"
Write-Host "==========================================" -ForegroundColor Red
