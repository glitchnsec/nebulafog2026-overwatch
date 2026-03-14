# =============================================================================
# Wizard Spider Adversary Emulation Lab — Complete Terraform Configuration
# =============================================================================
# FIXED: Linux provisioning uses remote-exec (visible, retryable) instead of
# user_data (silent failures, no reruns). Windows keeps user_data for bootstrap
# since RDP/WinRM provisioners are less reliable.
#
# Usage:
#   terraform init
#   terraform apply \
#     -var="key_name=wizard-spider-lab" \
#     -var="private_key_path=./wizard-spider-lab.pem" \
#     -var="my_ip=$(curl -s ifconfig.me)/32"
#
# Teardown:
#   terraform destroy -auto-approve
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# =============================================================================
# VARIABLES
# =============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ca-central-1"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "private_key_path" {
  description = "Local path to the private key file (e.g. ./wizard-spider-lab.pem)"
  type        = string
}

variable "my_ip" {
  description = "Your public IP in CIDR notation (e.g. 203.0.113.42/32)"
  type        = string
}

variable "win_password" {
  description = "Administrator password for all Windows hosts"
  type        = string
  sensitive   = true
  default     = "WizSpider-Lab2024!"
}

# =============================================================================
# AMI LOOKUPS
# =============================================================================

data "aws_ami" "windows_server_2019" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  win_ami    = data.aws_ami.windows_server_2019.id
  ubuntu_ami = data.aws_ami.ubuntu_2204.id
  common_tags = {
    Project   = "wizard-spider-emulation"
    ManagedBy = "terraform"
  }
}

# =============================================================================
# NETWORKING
# =============================================================================

resource "aws_vpc" "lab" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, { Name = "wizard-spider-vpc" })
}

resource "aws_subnet" "victim" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, { Name = "victim-subnet" })
}

resource "aws_subnet" "attacker" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, { Name = "attacker-subnet" })
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.lab.id
  tags   = merge(local.common_tags, { Name = "lab-igw" })
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = merge(local.common_tags, { Name = "lab-rt" })
}

resource "aws_route_table_association" "victim" {
  subnet_id      = aws_subnet.victim.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "attacker" {
  subnet_id      = aws_subnet.attacker.id
  route_table_id = aws_route_table.main.id
}

# =============================================================================
# SECURITY GROUP
# =============================================================================

resource "aws_security_group" "lab" {
  name   = "wizard-spider-lab"
  vpc_id = aws_vpc.lab.id

  # All internal
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Operator access
  dynamic "ingress" {
    for_each = [22, 3389, 5601, 8888, 5000, 9200]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.my_ip]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "lab-sg" })
}

# =============================================================================
# WINDOWS HOSTS — user_data only (simple PowerShell, no external downloads)
# =============================================================================

# --- Wizard DC ---
resource "aws_instance" "wizard_dc" {
  ami                    = local.win_ami
  instance_type          = "t3.xlarge"
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.6"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab.id]
  root_block_device { volume_size = 60; volume_type = "gp3" }

  user_data = <<-EOF
    <powershell>
    $ErrorActionPreference = "Continue"
    $pw = ConvertTo-SecureString "${var.win_password}" -AsPlainText -Force
    Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $pw
    Rename-Computer -NewName "WIZARD" -Force
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Import-Module ADDSDeployment
    Install-ADDSForest -DomainName "oz.local" -DomainNetBIOSName "OZ" -SafeModeAdministratorPassword $pw -InstallDns -NoRebootOnCompletion:$false -Force
    </powershell>
  EOF

  tags = merge(local.common_tags, { Name = "Wizard-DC", Role = "domain-controller" })
}

# --- Domain join template used by Dorothy, Toto, Glinda ---
locals {
  domain_join_userdata = <<-EOF
    <powershell>
    $ErrorActionPreference = "Continue"
    $pw = ConvertTo-SecureString "${var.win_password}" -AsPlainText -Force
    Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $pw
    Rename-Computer -NewName "YOURHOST" -Force
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses "10.0.1.6"
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    $script = @'
    try {
      $c = New-Object PSCredential("OZ\Administrator", (ConvertTo-SecureString "${var.win_password}" -AsPlainText -Force))
      Add-Computer -DomainName "oz.local" -Credential $c -Restart -Force
      Unregister-ScheduledTask -TaskName "JoinDomain" -Confirm:$false
    } catch { Write-Output "DC not ready, retrying..." }
    '@
    $script | Out-File C:\join-domain.ps1
    $a = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\join-domain.ps1"
    $t = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Minutes 2) -RepetitionDuration (New-TimeSpan -Hours 1)
    Register-ScheduledTask -TaskName "JoinDomain" -Action $a -Trigger $t -User "SYSTEM" -RunLevel Highest
    Restart-Computer -Force
    </powershell>
  EOF
}

# --- Dorothy ---
resource "aws_instance" "dorothy" {
  ami                    = local.win_ami
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.4"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab.id]
  depends_on             = [aws_instance.wizard_dc]
  root_block_device { volume_size = 40; volume_type = "gp3" }
  user_data = replace(local.domain_join_userdata, "YOURHOST", "DOROTHY")
  tags = merge(local.common_tags, { Name = "Dorothy-Workstation", Role = "initial-victim" })
}

# --- Toto ---
resource "aws_instance" "toto" {
  ami                    = local.win_ami
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.5"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab.id]
  depends_on             = [aws_instance.wizard_dc]
  root_block_device { volume_size = 40; volume_type = "gp3" }
  user_data = replace(local.domain_join_userdata, "YOURHOST", "TOTO")
  tags = merge(local.common_tags, { Name = "Toto-Workstation", Role = "lateral-target" })
}

# --- Glinda ---
resource "aws_instance" "glinda" {
  ami                    = local.win_ami
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.7"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab.id]
  depends_on             = [aws_instance.wizard_dc]
  root_block_device { volume_size = 60; volume_type = "gp3" }

  user_data = <<-EOF
    <powershell>
    $ErrorActionPreference = "Continue"
    $pw = ConvertTo-SecureString "${var.win_password}" -AsPlainText -Force
    Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $pw
    Rename-Computer -NewName "GLINDA" -Force
    Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses "10.0.1.6"
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    $script = @'
    try {
      $c = New-Object PSCredential("OZ\Administrator", (ConvertTo-SecureString "${var.win_password}" -AsPlainText -Force))
      Add-Computer -DomainName "oz.local" -Credential $c -Restart -Force
      Unregister-ScheduledTask -TaskName "JoinDomain" -Confirm:$false
    } catch { Write-Output "DC not ready, retrying..." }
    '@
    $script | Out-File C:\join-domain.ps1
    $a = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\join-domain.ps1"
    $t = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Minutes 2) -RepetitionDuration (New-TimeSpan -Hours 1)
    Register-ScheduledTask -TaskName "JoinDomain" -Action $a -Trigger $t -User "SYSTEM" -RunLevel Highest
    Restart-Computer -Force
    </powershell>
  EOF

  tags = merge(local.common_tags, { Name = "Glinda-Backup", Role = "backup-server" })
}

# =============================================================================
# LINUX HOSTS — Instances are bare; provisioning via remote-exec
# =============================================================================

# --- ELK Instance (bare) ---
resource "aws_instance" "elk" {
  ami                    = local.ubuntu_ami
  instance_type          = "t3.xlarge"
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.10"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab.id]
  root_block_device { volume_size = 100; volume_type = "gp3" }
  tags = merge(local.common_tags, { Name = "ELK-SIEM", Role = "logging-pipeline" })
}

# --- ELK Provisioner ---
resource "null_resource" "provision_elk" {
  depends_on = [aws_instance.elk]

  triggers = {
    instance_id = aws_instance.elk.id
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = aws_instance.elk.public_ip
    timeout     = "5m"
  }

  # Upload scripts
  provisioner "file" {
    source      = "${path.module}/scripts/setup-elk.sh"
    destination = "/home/ubuntu/setup-elk.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/logstash-pipeline.conf"
    destination = "/home/ubuntu/logstash-pipeline.conf"
  }

  # Run setup
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/setup-elk.sh",
      "sudo /home/ubuntu/setup-elk.sh",
      "sudo cp /home/ubuntu/logstash-pipeline.conf /opt/elk/logstash/pipeline/logstash.conf",
      "cd /opt/elk && sudo docker compose restart logstash",
    ]
  }
}

# --- Attack Platform Instance (bare) ---
resource "aws_instance" "attack_platform" {
  ami                    = local.ubuntu_ami
  instance_type          = "t3.xlarge"
  subnet_id              = aws_subnet.attacker.id
  private_ip             = "10.0.2.4"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab.id]
  root_block_device { volume_size = 80; volume_type = "gp3" }
  tags = merge(local.common_tags, { Name = "Attack-Platform", Role = "caldera-c2" })
}

# --- CALDERA Provisioner ---
resource "null_resource" "provision_caldera" {
  depends_on = [aws_instance.attack_platform]

  triggers = {
    instance_id = aws_instance.attack_platform.id
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = aws_instance.attack_platform.public_ip
    timeout     = "5m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup-caldera.sh"
    destination = "/home/ubuntu/setup-caldera.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/setup-caldera.sh",
      "sudo /home/ubuntu/setup-caldera.sh",
    ]
  }
}

# =============================================================================
# POST-PROVISION SCRIPTS (generated locally for manual use on Windows hosts)
# =============================================================================

resource "local_file" "ad_setup_script" {
  filename = "${path.module}/scripts/setup-ad-users.ps1"
  content  = <<-'PS1'
    # Run on Wizard DC after AD DS promotion completes (~10 min after boot)
    # RDP in as Administrator
    $ErrorActionPreference = "Continue"
    Import-Module ActiveDirectory

    New-ADOrganizationalUnit -Name "OZ_Users" -Path "DC=oz,DC=local" -ErrorAction SilentlyContinue
    New-ADOrganizationalUnit -Name "OZ_Computers" -Path "DC=oz,DC=local" -ErrorAction SilentlyContinue

    $pw = ConvertTo-SecureString "WizSpider-Lab2024!" -AsPlainText -Force

    New-ADUser -Name "Dorothy Gale" -SamAccountName "dorothy" -UserPrincipalName "dorothy@oz.local" -AccountPassword $pw -Enabled $true -Path "OU=OZ_Users,DC=oz,DC=local" -PasswordNeverExpires $true -ErrorAction SilentlyContinue
    New-ADUser -Name "Bill" -SamAccountName "bill" -UserPrincipalName "bill@oz.local" -AccountPassword $pw -Enabled $true -Path "OU=OZ_Users,DC=oz,DC=local" -PasswordNeverExpires $true -ErrorAction SilentlyContinue
    Add-ADGroupMember -Identity "Domain Admins" -Members "bill" -ErrorAction SilentlyContinue

    New-ADUser -Name "SQLService" -SamAccountName "sqlservice" -UserPrincipalName "sqlservice@oz.local" -AccountPassword $pw -Enabled $true -Path "OU=OZ_Users,DC=oz,DC=local" -PasswordNeverExpires $true -ErrorAction SilentlyContinue
    setspn -A MSSQLSvc/wizard.oz.local:1433 oz\sqlservice

    Set-DnsServerForwarder -IPAddress "8.8.8.8" -ErrorAction SilentlyContinue

    auditpol /set /subcategory:"Logon" /success:enable /failure:enable
    auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable
    auditpol /set /subcategory:"Kerberos Service Ticket Operations" /success:enable /failure:enable
    auditpol /set /subcategory:"Process Creation" /success:enable
    auditpol /set /subcategory:"Registry" /success:enable
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f

    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name "EnableModuleLogging" -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" -Name "*" -Value "*"

    Write-Output "=== AD setup complete: dorothy, bill (DA), sqlservice (SPN) ==="
  PS1
}

resource "local_file" "sysmon_winlogbeat_script" {
  filename = "${path.module}/scripts/install-sysmon-winlogbeat.ps1"
  content  = <<-'PS1'
    # Run on EACH Windows host after domain join
    $ErrorActionPreference = "Continue"

    # --- Sysmon ---
    New-Item -Path "C:\Tools\Sysmon" -ItemType Directory -Force | Out-Null
    Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "C:\Tools\Sysmon\Sysmon.zip"
    Expand-Archive "C:\Tools\Sysmon\Sysmon.zip" -DestinationPath "C:\Tools\Sysmon" -Force
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml" -OutFile "C:\Tools\Sysmon\sysmonconfig.xml"
    & "C:\Tools\Sysmon\Sysmon64.exe" -accepteula -i "C:\Tools\Sysmon\sysmonconfig.xml"

    # --- Winlogbeat ---
    Invoke-WebRequest -Uri "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-8.17.0-windows-x86_64.zip" -OutFile "C:\Tools\winlogbeat.zip"
    Expand-Archive "C:\Tools\winlogbeat.zip" -DestinationPath "C:\Program Files" -Force
    $src = "C:\Program Files\winlogbeat-8.17.0-windows-x86_64"
    $dst = "C:\Program Files\Winlogbeat"
    if (Test-Path $src) { Rename-Item $src $dst -ErrorAction SilentlyContinue }

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
"@ | Set-Content "C:\Program Files\Winlogbeat\winlogbeat.yml" -Encoding UTF8

    Set-Location "C:\Program Files\Winlogbeat"
    .\install-service-winlogbeat.ps1
    Start-Service winlogbeat

    Write-Output "Sysmon:    $(Get-Service Sysmon64 | Select-Object -ExpandProperty Status)"
    Write-Output "Winlogbeat: $(Get-Service winlogbeat | Select-Object -ExpandProperty Status)"
  PS1
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "wizard_dc_public_ip"      { value = aws_instance.wizard_dc.public_ip }
output "dorothy_public_ip"        { value = aws_instance.dorothy.public_ip }
output "toto_public_ip"           { value = aws_instance.toto.public_ip }
output "glinda_public_ip"         { value = aws_instance.glinda.public_ip }
output "attack_platform_public_ip"{ value = aws_instance.attack_platform.public_ip }
output "elk_public_ip"            { value = aws_instance.elk.public_ip }

output "connection_info" {
  description = "Quick-reference connection commands"
  value = <<-EOT

    ================================================
    WIZARD SPIDER EMULATION LAB
    ================================================

    DOMAIN CONTROLLER (Wizard):
      RDP:  ${aws_instance.wizard_dc.public_ip}
      User: Administrator / WizSpider-Lab2024!

    DOROTHY (Initial Victim):
      RDP:  ${aws_instance.dorothy.public_ip}

    TOTO (Lateral Movement):
      RDP:  ${aws_instance.toto.public_ip}

    GLINDA (Backup Server):
      RDP:  ${aws_instance.glinda.public_ip}

    ATTACK PLATFORM (CALDERA):
      SSH:  ssh -i ${var.private_key_path} ubuntu@${aws_instance.attack_platform.public_ip}
      UI:   http://${aws_instance.attack_platform.public_ip}:8888
      Cred: red / admin

    ELK SIEM:
      SSH:    ssh -i ${var.private_key_path} ubuntu@${aws_instance.elk.public_ip}
      Kibana: http://${aws_instance.elk.public_ip}:5601

    INTERNAL IPs:
      Dorothy: 10.0.1.4    Toto:   10.0.1.5
      Wizard:  10.0.1.6    Glinda: 10.0.1.7
      ELK:     10.0.1.10   Attack: 10.0.2.4

    POST-PROVISION (manual on Windows):
      1. RDP to Wizard DC → run scripts/setup-ad-users.ps1
      2. RDP to each Windows host → run scripts/install-sysmon-winlogbeat.ps1

    TEARDOWN:
      terraform destroy -auto-approve

  EOT
  sensitive = true
}
