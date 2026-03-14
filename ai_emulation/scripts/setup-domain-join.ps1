# =============================================================================
# Step 3: Run on Dorothy, Toto, and Glinda to join oz.local
# RDP as Administrator / WizSpider-Lab2024!
#
# >>> EDIT THE HOSTNAME BELOW BEFORE RUNNING <<<
# =============================================================================

$HOSTNAME = "YOURHOST"   # <-- Change to: DOROTHY, TOTO, or GLINDA

$ErrorActionPreference = "Continue"

# Rename
Rename-Computer -NewName $HOSTNAME -Force

# Point DNS to Domain Controller
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses "10.0.1.6"

# Test DC reachability
Write-Output "Testing DNS resolution of oz.local..."
$result = Resolve-DnsName "oz.local" -ErrorAction SilentlyContinue
if (-not $result) {
    Write-Output "ERROR: Cannot resolve oz.local. Is the DC running and promoted?"
    Write-Output "Check: nslookup oz.local 10.0.1.6"
    exit 1
}
Write-Output "OK - oz.local resolves"

# Install backup feature on Glinda only
if ($HOSTNAME -eq "GLINDA") {
    Write-Output "Installing Windows Server Backup..."
    Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools
}

# Join domain
$cred = New-Object PSCredential("OZ\Administrator",
  (ConvertTo-SecureString "WizSpider-Lab2024!" -AsPlainText -Force))

Write-Output "Joining oz.local domain..."
Add-Computer -DomainName "oz.local" -Credential $cred -Restart -Force
