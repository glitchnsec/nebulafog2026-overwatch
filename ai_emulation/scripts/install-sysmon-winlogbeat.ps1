    # =============================================================
    # Run this on EACH Windows host (Dorothy, Toto, Wizard, Glinda)
    # via RDP or WinRM after domain join is complete
    # =============================================================

    $ErrorActionPreference = "Continue"

    # --- Install Sysmon ---
    $sysmonDir = "C:\Tools\Sysmon"
    New-Item -Path $sysmonDir -ItemType Directory -Force | Out-Null

    Write-Output "Downloading Sysmon..."
    Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" `
      -OutFile "$sysmonDir\Sysmon.zip"
    Expand-Archive "$sysmonDir\Sysmon.zip" -DestinationPath $sysmonDir -Force

    Write-Output "Downloading sysmon-modular config..."
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml" `
      -OutFile "$sysmonDir\sysmonconfig.xml"

    Write-Output "Installing Sysmon service..."
    & "$sysmonDir\Sysmon64.exe" -accepteula -i "$sysmonDir\sysmonconfig.xml" 2>&1

    # --- Install Winlogbeat ---
    $wbVersion = "8.17.0"
    $wbDir = "C:\Program Files\Winlogbeat"

    Write-Output "Downloading Winlogbeat..."
    Invoke-WebRequest -Uri "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-$wbVersion-windows-x86_64.zip" `
      -OutFile "C:\Tools\winlogbeat.zip"
    Expand-Archive "C:\Tools\winlogbeat.zip" -DestinationPath "C:\Program Files" -Force
    if (Test-Path "C:\Program Files\winlogbeat-$wbVersion-windows-x86_64") {
      Rename-Item "C:\Program Files\winlogbeat-$wbVersion-windows-x86_64" $wbDir -ErrorAction SilentlyContinue
    }

    # --- Configure Winlogbeat ---
    Write-Output "Configuring Winlogbeat..."
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

logging.level: info
logging.to_files: true
logging.files:
  path: C:\Program Files\Winlogbeat\logs
"@ | Set-Content "$wbDir\winlogbeat.yml" -Encoding UTF8

    # --- Install and start Winlogbeat service ---
    Write-Output "Installing Winlogbeat service..."
    Set-Location $wbDir
    .\install-service-winlogbeat.ps1 2>&1
    Start-Service winlogbeat

    Write-Output "=== Sysmon + Winlogbeat installation complete ==="
    Write-Output "Sysmon service: $(Get-Service Sysmon64 | Select-Object -ExpandProperty Status)"
    Write-Output "Winlogbeat service: $(Get-Service winlogbeat | Select-Object -ExpandProperty Status)"
