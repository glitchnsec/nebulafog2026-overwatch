
scp -i wizard-spider-lab.pem scripts/setup-elk.sh ubuntu@$(terraform output -raw elk):~
ssh -i wizard-spider-lab.pem ubuntu@$(terraform output -raw elk) "sudo bash setup-elk.sh"

# 2. CALDERA (parallel with ELK in another terminal)
scp -i wizard-spider-lab.pem scripts/setup-caldera.sh ubuntu@$(terraform output -raw attack_platform):~
ssh -i wizard-spider-lab.pem ubuntu@$(terraform output -raw attack_platform) "sudo bash setup-caldera.sh"

# 3. RDP to Wizard DC → paste setup-dc.ps1 → wait for reboot (~5 min)
# 4. RDP to Wizard DC again → paste setup-ad-users.ps1
# 5. RDP to Dorothy/Toto/Glinda → edit hostname in setup-domain-join.ps1 → paste
# 6. RDP to all 4 Windows hosts → paste setup-sysmon-winlogbeat.ps1