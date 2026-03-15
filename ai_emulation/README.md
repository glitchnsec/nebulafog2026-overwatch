Uses terraform to deploy victim and attacker infrastructure and then some manually scripting!

generate key pair

```sh
#aws ec2 delete-key-pair --key-name wizard-spider-lab


aws ec2 create-key-pair \
  --key-name wizard-spider-lab \
  --key-type rsa \
  --query "KeyMaterial" \
  --output text > wizard-spider-lab.pem

chmod 400 wizard-spider-lab.pem
```

create infra

```sh
terraform apply \
  -var="key_name=wizard-spider-lab" \
  -var="my_ip=$(curl -s ifconfig.me)/32"
```

destroy infra

```sh
terraform destroy -auto-approve \
  -var="key_name=wizard-spider-lab" \
  -var="my_ip=$(curl -s ifconfig.me)/32"
```

Example output:

```txt
attack_platform = "3.96.198.17"
dorothy = "99.79.48.57"
elk = "15.223.1.249"
glinda = "35.182.177.173"
quick_ref = <<EOT

=== SSH (Linux) ===
ELK: ssh -i <key>.pem ubuntu@15.223.1.249
CALDERA: ssh -i <key>.pem ubuntu@3.96.198.17

=== RDP (Windows) — Administrator / WizSpider-Lab2024! ===
Wizard DC: 99.79.51.106
Dorothy: 99.79.48.57
Toto: 35.183.131.12
Glinda: 35.182.177.173

=== Run order ===

1. ssh ELK -> sudo bash setup-elk.sh
2. ssh CALDERA -> sudo bash setup-caldera.sh
3. RDP Wizard DC -> paste setup-dc.ps1 (reboots)
4. RDP Wizard DC -> paste setup-ad-users.ps1 (after reboot)
5. RDP Dorothy/Toto/Glinda -> paste setup-domain-join.ps1
6. RDP all Windows hosts -> paste setup-sysmon-winlogbeat.ps1

EOT
toto = "35.183.131.12"
wizard_dc = "99.79.51.106"
```

---

SETUP MACHINES

```
scp -i wizard-spider-lab.pem scripts/setup-elk.sh ubuntu@$(terraform output -raw elk):~
ssh -i wizard-spider-lab.pem ubuntu@$(terraform output -raw elk) "sudo bash setup-elk.sh"
```

# 2. CALDERA (parallel with ELK in another terminal)

```
scp -i wizard-spider-lab.pem scripts/setup-caldera.sh ubuntu@$(terraform output -raw attack_platform):~
ssh -i wizard-spider-lab.pem ubuntu@$(terraform output -raw attack_platform) "sudo bash setup-caldera.sh"
```

# 3. RDP to Wizard DC → paste setup-dc.ps1 → wait for reboot (~5 min)

# 4. RDP to Wizard DC again → paste setup-ad-users.ps1

# 5. RDP to Dorothy/Toto/Glinda → edit hostname in setup-domain-join.ps1 → paste

# 6. RDP to all 4 Windows hosts → paste setup-sysmon-winlogbeat.ps1
