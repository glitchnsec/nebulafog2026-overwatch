# =============================================================================
# Step 1: Run on Wizard DC (10.0.1.6) — Promotes to Domain Controller
# RDP as Administrator / WizSpider-Lab2024!
# NOTE: This REBOOTS the machine. Reconnect after ~5 min.
# =============================================================================

$ErrorActionPreference = "Continue"
$pw = ConvertTo-SecureString "WizSpider-Lab2024!" -AsPlainText -Force

Rename-Computer -NewName "WIZARD" -Force

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Import-Module ADDSDeployment
Install-ADDSForest `
  -DomainName "oz.local" `
  -DomainNetBIOSName "OZ" `
  -SafeModeAdministratorPassword $pw `
  -InstallDns `
  -NoRebootOnCompletion:$false `
  -Force

# Machine reboots here. Reconnect via RDP, then run setup-ad-users.ps1
