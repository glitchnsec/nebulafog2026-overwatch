# =============================================================
# Run this on the Domain Controller (Wizard) after it reboots
# from AD DS forest promotion (~10 min after launch)
# RDP to: <wizard_public_ip> as Administrator
# =============================================================

# Wait for AD DS to be ready
while (-not (Get-Service NTDS -ErrorAction SilentlyContinue)) {
  Write-Output "Waiting for AD DS service..."
  Start-Sleep -Seconds 30
}

Import-Module ActiveDirectory

# Create OUs
New-ADOrganizationalUnit -Name "OZ_Users" -Path "DC=oz,DC=local" -ErrorAction SilentlyContinue
New-ADOrganizationalUnit -Name "OZ_Computers" -Path "DC=oz,DC=local" -ErrorAction SilentlyContinue
New-ADOrganizationalUnit -Name "OZ_Servers" -Path "DC=oz,DC=local" -ErrorAction SilentlyContinue

$pw = ConvertTo-SecureString "WizSpider-Lab2024!" -AsPlainText -Force

# Dorothy — initial victim user
New-ADUser -Name "Dorothy Gale" -SamAccountName "dorothy" `
  -UserPrincipalName "dorothy@oz.local" -AccountPassword $pw `
  -Enabled $true -Path "OU=OZ_Users,DC=oz,DC=local" `
  -PasswordNeverExpires $true -ErrorAction SilentlyContinue

# Bill — credentials harvested via Emotet email scraping
New-ADUser -Name "Bill" -SamAccountName "bill" `
  -UserPrincipalName "bill@oz.local" -AccountPassword $pw `
  -Enabled $true -Path "OU=OZ_Users,DC=oz,DC=local" `
  -PasswordNeverExpires $true -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity "Domain Admins" -Members "bill" -ErrorAction SilentlyContinue

# SQL Service account — Kerberoasting target
New-ADUser -Name "SQLService" -SamAccountName "sqlservice" `
  -UserPrincipalName "sqlservice@oz.local" -AccountPassword $pw `
  -Enabled $true -Path "OU=OZ_Users,DC=oz,DC=local" `
  -PasswordNeverExpires $true -ErrorAction SilentlyContinue
setspn -A MSSQLSvc/wizard.oz.local:1433 oz\sqlservice

# DNS forwarder for external resolution
Set-DnsServerForwarder -IPAddress "8.8.8.8" -ErrorAction SilentlyContinue

# Enable advanced audit policies
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable
auditpol /set /subcategory:"Kerberos Service Ticket Operations" /success:enable /failure:enable
auditpol /set /subcategory:"Process Creation" /success:enable
auditpol /set /subcategory:"Registry" /success:enable

# Enable command-line in process creation events
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
  /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f

# Enable PowerShell ScriptBlock Logging
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" `
  -Name "EnableScriptBlockLogging" -Value 1

# Enable PowerShell Module Logging
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" `
  -Name "EnableModuleLogging" -Value 1
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" `
  -Name "*" -Value "*"

Write-Output "=== AD setup complete ==="
Write-Output "Users created: dorothy, bill (Domain Admin), sqlservice (SPN set)"
Write-Output "Audit policies configured"
