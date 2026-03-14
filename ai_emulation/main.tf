terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = var.aws_region }

# --- Variables ---

variable "aws_region"  { default = "us-east-1" }
variable "key_name"    { type = string }
variable "my_ip"       { type = string }

variable "win_password" {
  type      = string
  sensitive = true
  default   = "WizSpider-Lab2024!"
}

# --- AMI Lookups ---

data "aws_ami" "win2019" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name"; values = ["Windows_Server-2019-English-Full-Base-*"] }
  filter { name = "virtualization-type"; values = ["hvm"] }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter { name = "name"; values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] }
  filter { name = "virtualization-type"; values = ["hvm"] }
}

# --- Networking ---

resource "aws_vpc" "lab" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "wizard-spider-vpc" }
}

resource "aws_subnet" "victim" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "victim-subnet" }
}

resource "aws_subnet" "attacker" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "attacker-subnet" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.lab.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.lab.id
  route { cidr_block = "0.0.0.0/0"; gateway_id = aws_internet_gateway.gw.id }
}

resource "aws_route_table_association" "victim"   { subnet_id = aws_subnet.victim.id;   route_table_id = aws_route_table.rt.id }
resource "aws_route_table_association" "attacker" { subnet_id = aws_subnet.attacker.id; route_table_id = aws_route_table.rt.id }

# --- Security Group ---

resource "aws_security_group" "lab" {
  name   = "wizard-spider-lab"
  vpc_id = aws_vpc.lab.id

  ingress { from_port = 0;    to_port = 0;    protocol = "-1"; cidr_blocks = ["10.0.0.0/16"] }
  ingress { from_port = 22;   to_port = 22;   protocol = "tcp"; cidr_blocks = [var.my_ip] }
  ingress { from_port = 3389; to_port = 3389; protocol = "tcp"; cidr_blocks = [var.my_ip] }
  ingress { from_port = 5601; to_port = 5601; protocol = "tcp"; cidr_blocks = [var.my_ip] }
  ingress { from_port = 8888; to_port = 8888; protocol = "tcp"; cidr_blocks = [var.my_ip] }
  ingress { from_port = 9200; to_port = 9200; protocol = "tcp"; cidr_blocks = [var.my_ip] }
  egress  { from_port = 0;    to_port = 0;    protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}

# --- Windows: minimal user_data (password + hostname + RDP only) ---

locals {
  win_base = <<-EOF
    <powershell>
    $ErrorActionPreference = "Continue"
    $pw = ConvertTo-SecureString "${var.win_password}" -AsPlainText -Force
    Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $pw
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
    </powershell>
  EOF
}

resource "aws_instance" "wizard_dc" {
  ami                    = data.aws_ami.win2019.id
  instance_type          = "t3.xlarge"
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.6"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab.id]
  root_block_device { volume_size = 60; volume_type = "gp3" }
  user_data = local.win_base
  tags = { Name = "Wizard-DC" }
}

resource "aws_instance" "dorothy" {
  ami                    = data.aws_ami.win2019.id
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.4"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab.id]
  root_block_device { volume_size = 40; volume_type = "gp3" }
  user_data = local.win_base
  tags = { Name = "Dorothy-Workstation" }
}

resource "aws_instance" "toto" {
  ami                    = data.aws_ami.win2019.id
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.5"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab.id]
  root_block_device { volume_size = 40; volume_type = "gp3" }
  user_data = local.win_base
  tags = { Name = "Toto-Workstation" }
}

resource "aws_instance" "glinda" {
  ami                    = data.aws_ami.win2019.id
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.7"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab.id]
  root_block_device { volume_size = 60; volume_type = "gp3" }
  user_data = local.win_base
  tags = { Name = "Glinda-Backup" }
}

# --- Linux: completely bare ---

resource "aws_instance" "elk" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.xlarge"
  subnet_id              = aws_subnet.victim.id
  private_ip             = "10.0.1.10"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab.id]
  root_block_device { volume_size = 100; volume_type = "gp3" }
  tags = { Name = "ELK-SIEM" }
}

resource "aws_instance" "attack_platform" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.xlarge"
  subnet_id              = aws_subnet.attacker.id
  private_ip             = "10.0.2.4"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lab.id]
  root_block_device { volume_size = 80; volume_type = "gp3" }
  tags = { Name = "Attack-Platform" }
}

# --- Outputs ---

output "wizard_dc"        { value = aws_instance.wizard_dc.public_ip }
output "dorothy"           { value = aws_instance.dorothy.public_ip }
output "toto"              { value = aws_instance.toto.public_ip }
output "glinda"            { value = aws_instance.glinda.public_ip }
output "elk"               { value = aws_instance.elk.public_ip }
output "attack_platform"   { value = aws_instance.attack_platform.public_ip }

output "quick_ref" {
  value = <<-EOT

  === SSH into Linux hosts ===
  ssh -i <key>.pem ubuntu@${aws_instance.elk.public_ip}              # ELK
  ssh -i <key>.pem ubuntu@${aws_instance.attack_platform.public_ip}  # CALDERA

  === RDP into Windows hosts (Administrator / WizSpider-Lab2024!) ===
  Wizard DC:  ${aws_instance.wizard_dc.public_ip}
  Dorothy:    ${aws_instance.dorothy.public_ip}
  Toto:       ${aws_instance.toto.public_ip}
  Glinda:     ${aws_instance.glinda.public_ip}

  === Run order ===
  1. ssh ELK       → sudo bash setup-elk.sh
  2. ssh CALDERA   → sudo bash setup-caldera.sh
  3. RDP Wizard DC → paste setup-dc.ps1
  4. Wait ~10 min for DC to reboot from AD promotion
  5. RDP Wizard DC → paste setup-ad-users.ps1
  6. RDP each Windows host → paste setup-domain-join.ps1 (edit hostname)
  7. RDP each Windows host → paste setup-sysmon-winlogbeat.ps1

  EOT
}
