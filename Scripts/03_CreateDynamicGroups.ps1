<#
.SYNOPSIS
    Creates 2 dynamic groups based on user attributes
    Project 1 - Day 4
.DESCRIPTION
    Creates:
        - DG-AllFinance-Users: rule = user.department -eq "Finance"
        - DG-India-Users     : rule = user.country -eq "IN"
.NOTES
    Requires Entra ID P1 license (Developer tenant has this)
    Dynamic groups take 3-10 minutes to evaluate
#>

# ============================================================
# STEP 1 — CONNECT
# ============================================================
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Group.ReadWrite.All"

# ============================================================
# STEP 2 — DEFINE DYNAMIC GROUPS
# ============================================================
$dynamicGroups = @(
    @{
        Name = "DG-AllFinance-Users"
        Desc = "Dynamic group: all Finance department users"
        Rule = 'user.department -eq "Finance"'
    },
    @{
        Name = "DG-India-Users"
        Desc = "Dynamic group: all India-based users"
        Rule = 'user.country -eq "IN"'
    }
)

# ============================================================
# STEP 3 — CREATE EACH
# ============================================================
foreach ($g in $dynamicGroups) {
    try {
        $existing = Get-MgGroup -Filter "displayName eq '$($g.Name)'" -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "Already exists: $($g.Name)" -ForegroundColor Yellow
            continue
        }

        New-MgGroup `
            -DisplayName                   $g.Name `
            -Description                   $g.Desc `
            -MailEnabled:$false `
            -MailNickname                  ($g.Name -replace "-", "") `
            -SecurityEnabled:$true `
            -GroupTypes                    @("DynamicMembership") `
            -MembershipRule                $g.Rule `
            -MembershipRuleProcessingState "On" | Out-Null

        Write-Host "Created dynamic group: $($g.Name)" -ForegroundColor Green
        Write-Host "  Rule: $($g.Rule)" -ForegroundColor Gray
    }
    catch {
        Write-Host "Failed: $($g.Name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DYNAMIC GROUPS CREATED" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Wait 5-10 minutes for rule evaluation."
Write-Host "Then verify membership in Entra portal."
