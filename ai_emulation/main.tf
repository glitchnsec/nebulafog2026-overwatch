# =============================================================================
# Wizard Spider Adversary Emulation Lab — Complete Terraform Configuration
# =============================================================================
# Hosts: Dorothy, Toto, Wizard (DC), Glinda (Backup), Attack Platform, ELK SIEM
# Usage:
#   terraform init
#   terraform apply -var="key_name=YOUR_KEY" -var="my_ip=YOUR_PUBLIC_IP/32"
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
  description = "AWS region to deploy into"
  type        = string
  default     = "ca-central-1"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH/RDP access"
  type        = string
}

variable "my_ip" {
  description = "Your public IP in CIDR notation (e.g. 203.0.113.42/32) for RDP/SSH access"
  type        = string
}

variable "win_password" {
  description = "Administrator password for all Windows hosts"
  type        = string
  sensitive   = true
  default     = "WizSpider-Lab2024!"
}

variable "windows_server_ami" {
  description = "AMI ID for Windows Server 2019 Base"
  type        = string
  default     = ""  # Set below via data source if empty
}

variable "windows_10_ami" {
  description = "AMI ID for Windows 10 (or use Windows Server as substitute)"
  type        = string
  default     = ""  # Windows 10 AMIs require BYOL — see note below
}

variable "ubuntu_ami" {
  description = "AMI ID for Ubuntu 22.04 LTS"
  type        = string
  default     = ""  # Set below via data source if empty
}

# =============================================================================
# AMI LOOKUPS (auto-resolve latest if not overridden)
# =============================================================================

# Latest Windows Server 2019 Base
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

# Latest Ubuntu 22.04 LTS
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

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
  # Use overrides if provided, otherwise use data source lookups
  win_server_ami = var.windows_server_ami != "" ? var.windows_server_ami : data.aws_ami.windows_server_2019.id
  ubuntu_ami     = var.ubuntu_ami != "" ? var.ubuntu_ami : data.aws_ami.ubuntu_2204.id

  # NOTE: True Windows 10 AMIs require BYOL license. For lab purposes,
  # Windows Server 2019 works as a stand-in for workstations. If you have
  # a custom Windows 10 AMI, pass it via -var="windows_10_ami=ami-xxxxx"
  win_10_ami = var.windows_10_ami != "" ? var.windows_10_ami : local.win_server_ami

  common_tags = {
    Project     = "wizard-spider-emulation"
    Environment = "lab"
    ManagedBy   = "terraform"
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

# Victim subnet — all Windows hosts + ELK
resource "aws_subnet" "victim" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, { Name = "victim-subnet" })
}

# Attacker subnet — CALDERA attack platform
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
# SECURITY GROUPS
# =============================================================================

# Internal lab traffic — all hosts can talk to each other
resource "aws_security_group" "lab_internal" {
  name        = "wizard-spider-lab-internal"
  description = "Allow all traffic within the lab VPC"
  vpc_id      = aws_vpc.lab.id

  # All internal traffic
  ingress {
    description = "All traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # RDP from operator
  ingress {
    description = "RDP from operator IP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # SSH from operator
  ingress {
    description = "SSH from operator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Kibana from operator
  ingress {
    description = "Kibana from operator IP"
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # CALDERA UI from operator
  ingress {
    description = "CALDERA UI from operator IP"
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # MLflow UI from operator
  ingress {
    description = "MLflow from operator IP"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Outbound — allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "lab-internal-sg" })
}

# =============================================================================
# HOST 1: WIZARD — Domain Controller (Windows Server 2019)
# =============================================================================

resource "aws_instance" "wizard_dc" {
  ami                    = local.win_server_ami
  instance_type          = "t3.xlarge"   # 4 vCPU, 16GB — needed for AD DS
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.6"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab_internal.id]

  root_block_device {
    volume_size = 60
    volume_type = "gp3"
  }

  user_data = <<-USERDATA
    <powershell>
    # Set Administrator password
    $password = ConvertTo-SecureString "${var.win_password}" -AsPlainText -Force
    Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $password

    # Set hostname
    Rename-Computer -NewName "WIZARD" -Force

    # Install AD DS role
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

    # Promote to Domain Controller
    Import-Module ADDSDeployment
    Install-ADDSForest `
      -DomainName "oz.local" `
      -DomainNetBIOSName "OZ" `
      -SafeModeAdministratorPassword $password `
      -InstallDns `
      -NoRebootOnCompletion:$false `
      -Force

    # Machine will reboot after forest promotion
    </powershell>
  USERDATA

  tags = merge(local.common_tags, {
    Name = "Wizard-DC"
    Role = "domain-controller"
  })
}

# =============================================================================
# HOST 2: DOROTHY — Initial Victim Workstation
# =============================================================================

resource "aws_instance" "dorothy" {
  ami                    = local.win_10_ami
  instance_type          = "t3.large"    # 2 vCPU, 8GB
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.4"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab_internal.id]

  root_block_device {
    volume_size = 40
    volume_type = "gp3"
  }

  # Wait for DC to start (domain join will happen post-provision)
  depends_on = [aws_instance.wizard_dc]

  user_data = <<-USERDATA
    <powershell>
    $password = ConvertTo-SecureString "${var.win_password}" -AsPlainText -Force
    Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $password
    Rename-Computer -NewName "DOROTHY" -Force

    # Point DNS at the Domain Controller
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses "10.0.1.6"

    # Enable WinRM for remote configuration
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

    # Enable RDP
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
      -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

    # Create a scheduled task to join domain after DC is ready
    # (DC needs ~10 min to promote; this retries every 2 min)
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument @"
      -ExecutionPolicy Bypass -Command "
        try {
          `$cred = New-Object PSCredential('OZ\Administrator', (ConvertTo-SecureString '${var.win_password}' -AsPlainText -Force))
          Add-Computer -DomainName 'oz.local' -Credential `$cred -Restart -Force
          Unregister-ScheduledTask -TaskName 'JoinDomain' -Confirm:`$false
        } catch {
          Write-Output 'DC not ready yet, will retry...'
        }
      "
"@
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) `
      -RepetitionInterval (New-TimeSpan -Minutes 2) `
      -RepetitionDuration (New-TimeSpan -Hours 1)
    Register-ScheduledTask -TaskName "JoinDomain" -Action $action -Trigger $trigger `
      -User "SYSTEM" -RunLevel Highest

    Restart-Computer -Force
    </powershell>
  USERDATA

  tags = merge(local.common_tags, {
    Name = "Dorothy-Workstation"
    Role = "initial-victim"
  })
}

# =============================================================================
# HOST 3: TOTO — Lateral Movement Target
# =============================================================================

resource "aws_instance" "toto" {
  ami                    = local.win_10_ami
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.5"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab_internal.id]

  root_block_device {
    volume_size = 40
    volume_type = "gp3"
  }

  depends_on = [aws_instance.wizard_dc]

  user_data = <<-USERDATA
    <powershell>
    $password = ConvertTo-SecureString "${var.win_password}" -AsPlainText -Force
    Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $password
    Rename-Computer -NewName "TOTO" -Force

    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses "10.0.1.6"

    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
      -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument @"
      -ExecutionPolicy Bypass -Command "
        try {
          `$cred = New-Object PSCredential('OZ\Administrator', (ConvertTo-SecureString '${var.win_password}' -AsPlainText -Force))
          Add-Computer -DomainName 'oz.local' -Credential `$cred -Restart -Force
          Unregister-ScheduledTask -TaskName 'JoinDomain' -Confirm:`$false
        } catch {
          Write-Output 'DC not ready yet, will retry...'
        }
      "
"@
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) `
      -RepetitionInterval (New-TimeSpan -Minutes 2) `
      -RepetitionDuration (New-TimeSpan -Hours 1)
    Register-ScheduledTask -TaskName "JoinDomain" -Action $action -Trigger $trigger `
      -User "SYSTEM" -RunLevel Highest

    Restart-Computer -Force
    </powershell>
  USERDATA

  tags = merge(local.common_tags, {
    Name = "Toto-Workstation"
    Role = "lateral-movement-target"
  })
}

# =============================================================================
# HOST 4: GLINDA — Backup Server
# =============================================================================

resource "aws_instance" "glinda" {
  ami                    = local.win_server_ami
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.7"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab_internal.id]

  root_block_device {
    volume_size = 60
    volume_type = "gp3"
  }

  depends_on = [aws_instance.wizard_dc]

  user_data = <<-USERDATA
    <powershell>
    $password = ConvertTo-SecureString "${var.win_password}" -AsPlainText -Force
    Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $password
    Rename-Computer -NewName "GLINDA" -Force

    # Install Windows Server Backup feature
    Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools

    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses "10.0.1.6"

    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
      -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument @"
      -ExecutionPolicy Bypass -Command "
        try {
          `$cred = New-Object PSCredential('OZ\Administrator', (ConvertTo-SecureString '${var.win_password}' -AsPlainText -Force))
          Add-Computer -DomainName 'oz.local' -Credential `$cred -Restart -Force
          Unregister-ScheduledTask -TaskName 'JoinDomain' -Confirm:`$false
        } catch {
          Write-Output 'DC not ready yet, will retry...'
        }
      "
"@
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) `
      -RepetitionInterval (New-TimeSpan -Minutes 2) `
      -RepetitionDuration (New-TimeSpan -Hours 1)
    Register-ScheduledTask -TaskName "JoinDomain" -Action $action -Trigger $trigger `
      -User "SYSTEM" -RunLevel Highest

    Restart-Computer -Force
    </powershell>
  USERDATA

  tags = merge(local.common_tags, {
    Name = "Glinda-Backup"
    Role = "backup-server"
  })
}

# =============================================================================
# HOST 5: ATTACK PLATFORM — CALDERA + AI Agents
# =============================================================================

resource "aws_instance" "attack_platform" {
  ami                    = local.ubuntu_ami
  instance_type          = "t3.xlarge"   # 4 vCPU, 16GB — CALDERA + MCP + MLflow
  subnet_id              = aws_subnet.attacker.id
  private_ip             = "10.0.2.4"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab_internal.id]

  root_block_device {
    volume_size = 80
    volume_type = "gp3"
  }

  user_data = <<-USERDATA
    #!/bin/bash
    set -e

    # System updates
    apt-get update -y
    apt-get install -y git python3 python3-pip python3-venv golang-go unzip jq curl

    # Create lab user
    useradd -m -s /bin/bash operator || true
    echo "operator:${var.win_password}" | chpasswd
    usermod -aG sudo operator

    # Clone repos as operator
    su - operator -c '
      cd ~

      # Clone CALDERA with all plugins
      git clone https://github.com/mitre/caldera.git --recursive --tag 5.1.0
      cd caldera

      # Set up Python venv
      python3 -m venv .calderavenv
      source .calderavenv/bin/activate
      pip install -r requirements.txt

      # Enable plugins
      cat > conf/local.yml << CALDERA_CONF
host: 0.0.0.0
port: 8888
plugins:
  - sandcat
  - stockpile
  - emu
  - response
  - mcp
users:
  red:
    red: admin
  blue:
    blue: admin
CALDERA_CONF

      cd ~

      # Clone the adversary emulation library
      git clone https://github.com/center-for-threat-informed-defense/adversary_emulation_library.git

      # Decrypt Wizard Spider payloads
      cd adversary_emulation_library/wizard_spider
      python3 Resources/utilities/crypt_executables.py -i ./ -p malware --decrypt || true
    '

    echo "=== Attack platform bootstrap complete ==="
  USERDATA

  tags = merge(local.common_tags, {
    Name = "Attack-Platform"
    Role = "caldera-c2"
  })
}

# =============================================================================
# HOST 6: ELK — SIEM / Logging Pipeline
# =============================================================================

resource "aws_instance" "elk" {
  ami                    = local.ubuntu_ami
  instance_type          = "t3.xlarge"   # 4 vCPU, 16GB — Elasticsearch needs RAM
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.10"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab_internal.id]

  root_block_device {
    volume_size = 100    # Log retention
    volume_type = "gp3"
  }

  user_data = <<-USERDATA
    #!/bin/bash
    set -e

    # System updates + Docker install
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release jq

    # Install Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
      gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Increase vm.max_map_count for Elasticsearch
    sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf

    # Create ELK directory structure
    mkdir -p /opt/elk/logstash/pipeline
    cd /opt/elk

    # Docker Compose for ELK stack
    cat > docker-compose.yml << 'COMPOSE'
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.17.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - xpack.security.http.ssl.enabled=false
      - "ES_JAVA_OPTS=-Xms4g -Xmx4g"
    ports:
      - "9200:9200"
    volumes:
      - es-data:/usr/share/elasticsearch/data
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:9200/_cluster/health | grep -q 'green\\|yellow'"]
      interval: 10s
      timeout: 5s
      retries: 30
    restart: unless-stopped

  logstash:
    image: docker.elastic.co/logstash/logstash:8.17.0
    container_name: logstash
    depends_on:
      elasticsearch:
        condition: service_healthy
    ports:
      - "5044:5044"
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
    restart: unless-stopped

  kibana:
    image: docker.elastic.co/kibana/kibana:8.17.0
    container_name: kibana
    depends_on:
      elasticsearch:
        condition: service_healthy
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    restart: unless-stopped

volumes:
  es-data:
COMPOSE

    # Logstash pipeline with Wizard Spider TTP tagging
    cat > logstash/pipeline/wizard-spider.conf << 'PIPELINE'
input {
  beats {
    port => 5044
  }
}

filter {
  # ---- Sysmon Events ----
  if [winlog][channel] == "Microsoft-Windows-Sysmon/Operational" {

    # Process Creation (Event ID 1)
    if [winlog][event_id] == 1 {

      # Phase 1: Emotet macro spawns PowerShell
      if [winlog][event_data][ParentImage] =~ /(?i)winword\.exe/ and
         [winlog][event_data][Image] =~ /(?i)powershell\.exe/ {
        mutate { add_tag => ["T1059.001", "T1204.002", "phase1_emotet_macro"] }
      }

      # Phase 1: rundll32 loading Emotet/TrickBot DLL
      if [winlog][event_data][Image] =~ /(?i)rundll32\.exe/ and
         [winlog][event_data][CommandLine] =~ /\.dll/ {
        mutate { add_tag => ["T1218.011", "dll_execution"] }
      }

      # Phase 2: Rubeus kerberoasting
      if [winlog][event_data][CommandLine] =~ /(?i)rubeus/ {
        mutate { add_tag => ["T1558.003", "phase2_kerberoast"] }
      }

      # Phase 2: AdFind AD enumeration
      if [winlog][event_data][Image] =~ /(?i)adfind/ {
        mutate { add_tag => ["T1482", "T1087.002", "phase2_ad_enum"] }
      }

      # Phase 2: Net commands for discovery
      if [winlog][event_data][Image] =~ /(?i)net\.exe/ or
         [winlog][event_data][Image] =~ /(?i)net1\.exe/ {
        mutate { add_tag => ["T1087", "T1016", "discovery"] }
      }

      # Phase 3: vssadmin shadow copy deletion
      if [winlog][event_data][CommandLine] =~ /(?i)vssadmin.*delete/ {
        mutate { add_tag => ["T1490", "phase3_inhibit_recovery"] }
      }

      # Phase 3: Service stop (backup kill)
      if [winlog][event_data][CommandLine] =~ /(?i)(sc stop|net stop|taskkill)/ {
        mutate { add_tag => ["T1489", "phase3_service_stop"] }
      }

      # Phase 3: icacls / attrib permission changes (Ryuk)
      if [winlog][event_data][CommandLine] =~ /(?i)(icacls|attrib.*[\-\+][rsh])/ {
        mutate { add_tag => ["T1222.001", "phase3_ryuk_perms"] }
      }
    }

    # Network Connection (Event ID 3)
    if [winlog][event_id] == 3 {
      if [winlog][event_data][DestinationPort] == "8080" {
        mutate { add_tag => ["T1071.001", "T1571", "emotet_c2_callback"] }
      }
      if [winlog][event_data][DestinationPort] == "8888" {
        mutate { add_tag => ["caldera_agent_beacon"] }
      }
    }

    # File Creation (Event ID 11)
    if [winlog][event_id] == 11 {
      if [winlog][event_data][TargetFilename] =~ /(?i)\.(ryk|encrypted|locked)$/ {
        mutate { add_tag => ["T1486", "phase3_ryuk_encryption"] }
      }
    }

    # Registry Modification (Event ID 13)
    if [winlog][event_id] == 13 {
      if [winlog][event_data][TargetObject] =~ /(?i)CurrentVersion\\Run/ {
        mutate { add_tag => ["T1547.001", "persistence_run_key"] }
      }
    }

    # Process Access (Event ID 10) — credential dumping
    if [winlog][event_id] == 10 {
      if [winlog][event_data][TargetImage] =~ /(?i)lsass\.exe/ {
        mutate { add_tag => ["T1003.001", "credential_access_lsass"] }
      }
    }
  }

  # ---- Windows Security Events ----
  if [winlog][channel] == "Security" {
    # Kerberos TGS request with RC4 (kerberoasting indicator)
    if [winlog][event_id] == 4769 {
      if [winlog][event_data][TicketEncryptionType] == "0x17" {
        mutate { add_tag => ["T1558.003", "kerberoast_tgs_rc4"] }
      }
    }

    # RDP logon (Type 10)
    if [winlog][event_id] == 4624 {
      if [winlog][event_data][LogonType] == "10" {
        mutate { add_tag => ["T1021.001", "rdp_lateral_movement"] }
      }
    }

    # Explicit credential use (runas, etc.)
    if [winlog][event_id] == 4648 {
      mutate { add_tag => ["T1078.002", "explicit_credential_use"] }
    }

    # Special privilege assigned
    if [winlog][event_id] == 4672 {
      mutate { add_tag => ["T1134", "privilege_escalation"] }
    }
  }

  # ---- PowerShell Events ----
  if [winlog][channel] == "Microsoft-Windows-PowerShell/Operational" {
    if [winlog][event_id] == 4104 {
      mutate { add_tag => ["T1059.001", "powershell_scriptblock"] }
      if [message] =~ /(?i)(downloadstring|invoke-webrequest|invoke-expression|iex |bypass)/ {
        mutate { add_tag => ["suspicious_powershell_download"] }
      }
      if [message] =~ /(?i)(mimikatz|kerberoast|dump|credential)/ {
        mutate { add_tag => ["suspicious_powershell_credaccess"] }
      }
    }
  }

  # ---- Add ATT&CK phase metadata ----
  if "phase1" in [tags] { mutate { add_field => { "wizard_spider_phase" => "1_initial_access" } } }
  if "phase2" in [tags] { mutate { add_field => { "wizard_spider_phase" => "2_lateral_movement" } } }
  if "phase3" in [tags] { mutate { add_field => { "wizard_spider_phase" => "3_impact" } } }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    index => "winlogbeat-%%{+YYYY.MM.dd}"
  }
}
PIPELINE

    # Start the stack
    cd /opt/elk
    docker compose up -d

    echo "=== ELK stack bootstrap complete ==="
    echo "Kibana will be available at http://10.0.1.10:5601 in ~2 minutes"
  USERDATA

  tags = merge(local.common_tags, {
    Name = "ELK-SIEM"
    Role = "logging-pipeline"
  })
}

# =============================================================================
# POST-PROVISION SCRIPT: AD Users & SPNs
# (Run manually after DC reboots, or via SSM / remote-exec)
# =============================================================================

resource "local_file" "ad_setup_script" {
  filename = "${path.module}/scripts/setup-ad-users.ps1"
  content  = <<-PS1
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

    $pw = ConvertTo-SecureString "${var.win_password}" -AsPlainText -Force

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
  PS1
}

# =============================================================================
# POST-PROVISION SCRIPT: Sysmon + Winlogbeat on all Windows hosts
# =============================================================================

resource "local_file" "sysmon_winlogbeat_script" {
  filename = "${path.module}/scripts/install-sysmon-winlogbeat.ps1"
  content  = <<-PS1
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
  PS1
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "wizard_dc_public_ip" {
  description = "RDP into the Domain Controller"
  value       = aws_instance.wizard_dc.public_ip
}

output "dorothy_public_ip" {
  description = "RDP into Dorothy (initial victim)"
  value       = aws_instance.dorothy.public_ip
}

output "toto_public_ip" {
  description = "RDP into Toto (lateral movement target)"
  value       = aws_instance.toto.public_ip
}

output "glinda_public_ip" {
  description = "RDP into Glinda (backup server)"
  value       = aws_instance.glinda.public_ip
}

output "attack_platform_public_ip" {
  description = "SSH into the attack platform (CALDERA)"
  value       = aws_instance.attack_platform.public_ip
}

output "elk_public_ip" {
  description = "Kibana UI and ELK SIEM"
  value       = aws_instance.elk.public_ip
}

output "connection_info" {
  description = "Quick-reference connection commands"
  value = <<-EOT

    ========================================
    WIZARD SPIDER EMULATION LAB — CONNECTIONS
    ========================================

    Domain Controller (Wizard):
      RDP:  ${aws_instance.wizard_dc.public_ip}
      User: Administrator / ${var.win_password}

    Dorothy (Initial Victim):
      RDP:  ${aws_instance.dorothy.public_ip}
      User: OZ\dorothy / ${var.win_password}

    Toto (Lateral Movement):
      RDP:  ${aws_instance.toto.public_ip}

    Glinda (Backup Server):
      RDP:  ${aws_instance.glinda.public_ip}

    Attack Platform (CALDERA):
      SSH:  ssh -i <key.pem> ubuntu@${aws_instance.attack_platform.public_ip}
      UI:   http://${aws_instance.attack_platform.public_ip}:8888
      Cred: red / admin

    ELK SIEM:
      SSH:    ssh -i <key.pem> ubuntu@${aws_instance.elk.public_ip}
      Kibana: http://${aws_instance.elk.public_ip}:5601

    INTERNAL IPs:
      Dorothy:  10.0.1.4     Toto:     10.0.1.5
      Wizard:   10.0.1.6     Glinda:   10.0.1.7
      ELK:      10.0.1.10    Attack:   10.0.2.4

    TEARDOWN:
      terraform destroy -auto-approve

  EOT
  sensitive = true
}
