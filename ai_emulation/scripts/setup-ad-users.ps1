# =============================================================================
# Step 2: Run on Wizard DC AFTER it reboots from AD promotion
# RDP as OZ\Administrator / WizSpider-Lab2024!
# =============================================================================

$ErrorActionPreference = "Continue"
Import-Module ActiveDirectory

# --- OUs ---
New-ADOrganizationalUnit -Name "OZ_Users" -Path "DC=oz,DC=local" -ErrorAction SilentlyContinue
New-ADOrganizationalUnit -Name "OZ_Computers" -Path "DC=oz,DC=local" -ErrorAction SilentlyContinue

$pw = ConvertTo-SecureString "WizSpider-Lab2024!" -AsPlainText -Force

# --- Users ---
New-ADUser -Name "Dorothy Gale" -SamAccountName "dorothy" `
  -UserPrincipalName "dorothy@oz.local" -AccountPassword $pw `
  -Enabled $true -Path "OU=OZ_Users,DC=oz,DC=local" `
  -PasswordNeverExpires $true -ErrorAction SilentlyContinue

New-ADUser -Name "Bill" -SamAccountName "bill" `
  -UserPrincipalName "bill@oz.local" -AccountPassword $pw `
  -Enabled $true -Path "OU=OZ_Users,DC=oz,DC=local" `
  -PasswordNeverExpires $true -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity "Domain Admins" -Members "bill" -ErrorAction SilentlyContinue

New-ADUser -Name "SQLService" -SamAccountName "sqlservice" `
  -UserPrincipalName "sqlservice@oz.local" -AccountPassword $pw `
  -Enabled $true -Path "OU=OZ_Users,DC=oz,DC=local" `
  -PasswordNeverExpires $true -ErrorAction SilentlyContinue
setspn -A MSSQLSvc/wizard.oz.local:1433 oz\sqlservice

# --- DNS ---
Set-DnsServerForwarder -IPAddress "8.8.8.8" -ErrorAction SilentlyContinue

# --- Audit policies ---
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable
auditpol /set /subcategory:"Kerberos Service Ticket Operations" /success:enable /failure:enable
auditpol /set /subcategory:"Process Creation" /success:enable
auditpol /set /subcategory:"Registry" /success:enable

# --- Command-line in process creation ---
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
  /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f

# --- PowerShell logging ---
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" `
  -Name "EnableScriptBlockLogging" -Value 1

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" `
  -Name "EnableModuleLogging" -Value 1
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" `
  -Name "*" -Value "*"

# --- Verify ---
Write-Output ""
Write-Output "=== AD Setup Complete ==="
Get-ADUser -Filter * | Select-Object Name, SamAccountName, Enabled | Format-Table
setspn -L oz\sqlservice
