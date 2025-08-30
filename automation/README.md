# Microsoft Graph Automation Scripts

This directory contains PowerShell scripts for automating Microsoft Graph operations, primarily focused on Azure AD group management and user administration.

## Prerequisites

### Required Modules
Before using these scripts, ensure you have the Microsoft Graph PowerShell SDK installed:

```powershell
# Install the Microsoft Graph PowerShell module
Install-Module Microsoft.Graph -Scope CurrentUser -Force

# Install specific modules for authentication and groups
Install-Module Microsoft.Graph.Authentication -Force
Install-Module Microsoft.Graph.Groups -Force
Install-Module Microsoft.Graph.Users -Force
```

### Permissions Required
The following Microsoft Graph permissions are typically needed:
- `Group.ReadWrite.All` - For group management operations
- `User.Read.All` - For reading user information
- `GroupMember.ReadWrite.All` - For managing group memberships

## Authentication

### Interactive Authentication
```powershell
# Connect to Microsoft Graph with required scopes
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "GroupMember.ReadWrite.All"
```

### App-Only Authentication (Recommended for Production)
For automated scenarios, use certificate-based authentication:

```powershell
# Using certificate thumbprint
Connect-MgGraph -ClientId "your-app-id" -TenantId "your-tenant-id" -CertificateThumbprint "your-cert-thumbprint"

# Using certificate from file
$cert = Get-PfxCertificate -FilePath "C:\path\to\certificate.pfx"
Connect-MgGraph -ClientId "your-app-id" -TenantId "your-tenant-id" -Certificate $cert
```

## Available Scripts

### Remove-UserFromAllGroups.ps1
Removes a specified user from all Microsoft 365 groups they are a member of.

**Usage:**
```powershell
.\Remove-UserFromAllGroups.ps1 -UserPrincipalName "user@domain.com"
```

**Parameters:**
- `UserPrincipalName`: The UPN of the user to remove from groups
- `WhatIf` (optional): Preview changes without executing them

## Best Practices

### 1. Error Handling
Always implement proper error handling in your scripts:

```powershell
try {
    # Your Microsoft Graph operations
}
catch {
    Write-Error "Operation failed: $($_.Exception.Message)"
    # Log errors appropriately
}
```

### 2. Rate Limiting
Microsoft Graph implements throttling. Handle rate limits gracefully:

```powershell
# Implement retry logic with exponential backoff
$retryCount = 0
$maxRetries = 3

do {
    try {
        # Your Graph operation
        break
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 429) {
            $retryCount++
            $waitTime = [Math]::Pow(2, $retryCount)
            Start-Sleep -Seconds $waitTime
        }
        else {
            throw
        }
    }
} while ($retryCount -lt $maxRetries)
```

### 3. Logging
Implement comprehensive logging for audit and troubleshooting:

```powershell
# Set up logging
$logPath = "C:\Logs\GraphAutomation.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp [$Level] $Message" | Tee-Object -FilePath $logPath -Append
}
```

### 4. Testing
- Always test scripts in a non-production environment first
- Use the `-WhatIf` parameter when available
- Validate input parameters and user existence before operations

### 5. Security
- Store credentials securely (avoid hardcoding)
- Use managed identities in Azure when possible
- Follow principle of least privilege for API permissions
- Regularly rotate certificates and secrets

## Common Operations

### Get User Information
```powershell
$user = Get-MgUser -UserId "user@domain.com"
Write-Output "User: $($user.DisplayName) ($($user.UserPrincipalName))"
```

### List User's Group Memberships
```powershell
$groups = Get-MgUserMemberOf -UserId "user@domain.com"
$groups | Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group' }
```

### Remove User from Specific Group
```powershell
$groupId = "group-object-id"
$userId = "user-object-id"
Remove-MgGroupMemberByRef -GroupId $groupId -DirectoryObjectId $userId
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Ensure correct permissions are granted
   - Check tenant ID and application ID
   - Verify certificate is valid and accessible

2. **Permission Errors**
   - Confirm required Graph permissions are granted
   - Ensure admin consent has been provided
   - Check if conditional access policies are blocking access

3. **Rate Limiting**
   - Implement exponential backoff retry logic
   - Consider batching operations where possible
   - Monitor request patterns and optimize

### Debug Mode
Enable verbose output for troubleshooting:

```powershell
$VerbosePreference = "Continue"
$DebugPreference = "Continue"
```

## Contributing

When adding new scripts to this directory:

1. Follow PowerShell best practices
2. Include parameter validation
3. Add help documentation
4. Implement error handling
5. Test thoroughly
6. Update this README with usage instructions

## Resources

- [Microsoft Graph PowerShell SDK Documentation](https://docs.microsoft.com/en-us/powershell/microsoftgraph/)
- [Microsoft Graph API Reference](https://docs.microsoft.com/en-us/graph/api/overview)
- [Azure AD Group Management](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-groups-create-azure-portal)
- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)

---

*Last Updated: August 30, 2025*
