<#
.SYNOPSIS
    Bulk creates 16 users in Microsoft Entra ID for Contoso Finance Services
    Project 1 - Day 2
.DESCRIPTION
    Reads from CSV file and creates users with department, country, and other attributes.
    Required for dynamic group rules on Day 4.
.NOTES
    Author: Tilak Kalas
    Tenant: Replace "yourtenant.onmicrosoft.com" with your actual tenant domain
    Prerequisites: 
        - Microsoft.Graph PowerShell module installed
        - Global Administrator role
        - Project1_Graph_PowerShell.csv file in same folder
.EXAMPLE
    .\01_BulkCreateUsers.ps1
#>

# ============================================================
# STEP 1 — CONNECT TO MICROSOFT GRAPH
# ============================================================
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"

# ============================================================
# STEP 2 — IMPORT CSV
# ============================================================
$csvPath = ".\Project1_Graph_PowerShell.csv"

if (-not (Test-Path $csvPath)) {
    Write-Host "ERROR: CSV file not found at $csvPath" -ForegroundColor Red
    Write-Host "Please ensure Project1_Graph_PowerShell.csv is in the same folder." -ForegroundColor Yellow
    exit
}

$users = Import-Csv $csvPath
Write-Host "Found $($users.Count) users to create" -ForegroundColor Green

# ============================================================
# STEP 3 — CREATE EACH USER
# ============================================================
$created = 0
$failed = 0

foreach ($u in $users) {
    try {
        $PasswordProfile = @{
            Password                      = $u.Password
            ForceChangePasswordNextSignIn = $true
        }

        New-MgUser `
            -DisplayName        $u.DisplayName `
            -UserPrincipalName  $u.UserPrincipalName `
            -MailNickname       $u.MailNickname `
            -GivenName          $u.GivenName `
            -Surname            $u.Surname `
            -JobTitle           $u.JobTitle `
            -Department         $u.Department `
            -Country            $u.Country `
            -City               $u.City `
            -UsageLocation      $u.UsageLocation `
            -AccountEnabled:$true `
            -PasswordProfile    $PasswordProfile | Out-Null

        Write-Host "Created: $($u.DisplayName) [$($u.Department), $($u.Country)]" -ForegroundColor Green
        $created++
    }
    catch {
        Write-Host "Failed: $($u.DisplayName) - $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

# ============================================================
# STEP 4 — SUMMARY
# ============================================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Total users in CSV : $($users.Count)"
Write-Host "Successfully created: $created" -ForegroundColor Green
Write-Host "Failed             : $failed" -ForegroundColor Red
Write-Host ""
Write-Host "VERIFY: Open Entra portal -> Users to confirm" -ForegroundColor Yellow
