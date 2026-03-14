# =============================================================================
# Step 4: Run on EVERY Windows host (Wizard, Dorothy, Toto, Glinda)
# after domain join is complete
# =============================================================================

$ErrorActionPreference = "Continue"

# --- Sysmon ---
Write-Output "=== Installing Sysmon ==="
New-Item -Path "C:\Tools\Sysmon" -ItemType Directory -Force | Out-Null

Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" `
  -OutFile "C:\Tools\Sysmon\Sysmon.zip"
Expand-Archive "C:\Tools\Sysmon\Sysmon.zip" -DestinationPath "C:\Tools\Sysmon" -Force

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml" `
  -OutFile "C:\Tools\Sysmon\sysmonconfig.xml"

& "C:\Tools\Sysmon\Sysmon64.exe" -accepteula -i "C:\Tools\Sysmon\sysmonconfig.xml"

# --- Winlogbeat ---
Write-Output "=== Installing Winlogbeat ==="
$wbVersion = "8.17.0"

Invoke-WebRequest `
  -Uri "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-${wbVersion}-windows-x86_64.zip" `
  -OutFile "C:\Tools\winlogbeat.zip"
Expand-Archive "C:\Tools\winlogbeat.zip" -DestinationPath "C:\Program Files" -Force

$src = "C:\Program Files\winlogbeat-${wbVersion}-windows-x86_64"
$dst = "C:\Program Files\Winlogbeat"
if (Test-Path $src) { Rename-Item $src $dst -ErrorAction SilentlyContinue }

# --- Winlogbeat config ---
@"
winlogbeat.event_logs:
  - name: Application
    ignore_older: 72h
  - name: System
  - name: Security
  - name: Microsoft-Windows-Sysmon/Operational
    tags: [sysmon]
  - name: Windows PowerShell
    event_id: 400, 403, 600, 800
  - name: Microsoft-Windows-PowerShell/Operational
    event_id: 4103, 4104, 4105, 4106
  - name: Microsoft-Windows-TerminalServices-LocalSessionManager/Operational
    tags: [rdp]

output.logstash:
  hosts: ["10.0.1.10:5044"]

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
"@ | Set-Content "$dst\winlogbeat.yml" -Encoding UTF8

# --- Install & start services ---
Write-Output "=== Starting services ==="
Set-Location $dst
.\install-service-winlogbeat.ps1
Start-Service winlogbeat

# --- Verify ---
Write-Output ""
Write-Output "=== Status ==="
Write-Output "Sysmon:     $(Get-Service Sysmon64 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Status)"
Write-Output "Winlogbeat: $(Get-Service winlogbeat -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Status)"
