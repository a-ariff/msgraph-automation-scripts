<#
.SYNOPSIS
    Remove a user from all Microsoft 365 groups they are a member of.

.DESCRIPTION
    This script connects to Microsoft Graph and removes a specified user from all groups
    they are currently a member of. It provides detailed logging of the removal process.

.PARAMETER UserPrincipalName
    The User Principal Name (UPN) of the user to remove from all groups.

.PARAMETER TenantId
    The Azure AD Tenant ID.

.PARAMETER ClientId
    The Application (Client) ID of the registered Azure AD app.

.PARAMETER ClientSecret
    The client secret for the registered Azure AD app.

.EXAMPLE
    .\Remove-UserFromAllGroups.ps1 -UserPrincipalName "user@contoso.com" -TenantId "your-tenant-id" -ClientId "your-client-id" -ClientSecret "your-client-secret"

.NOTES
    Author: PowerShell Automation
    Date: $(Get-Date -Format 'yyyy-MM-dd')
    Requires: Microsoft.Graph PowerShell module
    Required Permissions: Group.ReadWrite.All, User.Read.All
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$UserPrincipalName,
    
    [Parameter(Mandatory = $true)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $true)]
    [string]$ClientId,
    
    [Parameter(Mandatory = $true)]
    [string]$ClientSecret
)

# Import required modules
try {
    Import-Module Microsoft.Graph.Authentication -Force
    Import-Module Microsoft.Graph.Groups -Force
    Import-Module Microsoft.Graph.Users -Force
    Write-Host "Successfully imported Microsoft Graph modules" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

# Function to connect to Microsoft Graph
function Connect-ToMSGraph {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )
    
    try {
        $SecureClientSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        $ClientCredential = New-Object System.Management.Automation.PSCredential($ClientId, $SecureClientSecret)
        
        Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientCredential -NoWelcome
        Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
        return $false
    }
}

# Function to get user ID from UPN
function Get-UserIdFromUPN {
    param([string]$UserPrincipalName)
    
    try {
        $User = Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'"
        if ($User) {
            Write-Host "Found user: $($User.DisplayName) ($($User.Id))" -ForegroundColor Green
            return $User.Id
        }
        else {
            Write-Error "User with UPN '$UserPrincipalName' not found"
            return $null
        }
    }
    catch {
        Write-Error "Error retrieving user: $($_.Exception.Message)"
        return $null
    }
}

# Function to get all groups for a user
function Get-UserGroups {
    param([string]$UserId)
    
    try {
        $Groups = Get-MgUserMemberOf -UserId $UserId | Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group' }
        Write-Host "User is a member of $($Groups.Count) groups" -ForegroundColor Yellow
        return $Groups
    }
    catch {
        Write-Error "Error retrieving user groups: $($_.Exception.Message)"
        return @()
    }
}

# Function to remove user from a group
function Remove-UserFromGroup {
    param(
        [string]$UserId,
        [string]$GroupId,
        [string]$GroupDisplayName
    )
    
    try {
        Remove-MgGroupMemberByRef -GroupId $GroupId -DirectoryObjectId $UserId
        Write-Host "Successfully removed user from group: $GroupDisplayName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "Failed to remove user from group '$GroupDisplayName': $($_.Exception.Message)"
        return $false
    }
}

# Main script execution
Write-Host "Starting Remove-UserFromAllGroups script" -ForegroundColor Cyan
Write-Host "Target User: $UserPrincipalName" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Connect to Microsoft Graph
if (-not (Connect-ToMSGraph -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret)) {
    exit 1
}

# Get user ID
$UserId = Get-UserIdFromUPN -UserPrincipalName $UserPrincipalName
if (-not $UserId) {
    Disconnect-MgGraph
    exit 1
}

# Get all groups for the user
$UserGroups = Get-UserGroups -UserId $UserId

if ($UserGroups.Count -eq 0) {
    Write-Host "User is not a member of any groups" -ForegroundColor Yellow
    Disconnect-MgGraph
    exit 0
}

# Remove user from each group
$SuccessCount = 0
$FailureCount = 0

Write-Host "\nStarting group removal process..." -ForegroundColor Cyan

foreach ($Group in $UserGroups) {
    $GroupDetails = Get-MgGroup -GroupId $Group.Id
    Write-Host "\nProcessing group: $($GroupDetails.DisplayName) ($($Group.Id))" -ForegroundColor Yellow
    
    if (Remove-UserFromGroup -UserId $UserId -GroupId $Group.Id -GroupDisplayName $GroupDetails.DisplayName) {
        $SuccessCount++
    }
    else {
        $FailureCount++
    }
    
    Start-Sleep -Milliseconds 500  # Brief pause to avoid throttling
}

# Summary
Write-Host "\n" + "="*50 -ForegroundColor Cyan
Write-Host "REMOVAL SUMMARY" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor Cyan
Write-Host "User: $UserPrincipalName" -ForegroundColor White
Write-Host "Total groups processed: $($UserGroups.Count)" -ForegroundColor White
Write-Host "Successfully removed from: $SuccessCount groups" -ForegroundColor Green
Write-Host "Failed removals: $FailureCount groups" -ForegroundColor $(if($FailureCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "Completion time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "="*50 -ForegroundColor Cyan

# Disconnect from Microsoft Graph
Disconnect-MgGraph
Write-Host "Disconnected from Microsoft Graph" -ForegroundColor Green

if ($FailureCount -gt 0) {
    Write-Warning "Script completed with $FailureCount failures. Please review the warnings above."
    exit 1
}
else {
    Write-Host "Script completed successfully. User removed from all groups." -ForegroundColor Green
    exit 0
}
