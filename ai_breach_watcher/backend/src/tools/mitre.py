"""MITRE ATT&CK lookup utilities for agents."""

# Subset of Wizard Spider-relevant techniques. Agents use this as a reference
# to map raw telemetry to techniques without relying on pre-tagged events.

TACTICS: dict[str, dict] = {
    "TA0001": {
        "name": "Initial Access",
        "techniques": {
            "T1566.001": "Spearphishing Attachment",
            "T1204.002": "User Execution: Malicious File",
        },
    },
    "TA0002": {
        "name": "Execution",
        "techniques": {
            "T1059.001": "PowerShell",
            "T1059.003": "Windows Command Shell",
            "T1047": "WMI",
            "T1218.011": "Rundll32",
            "T1053.005": "Scheduled Task",
        },
    },
    "TA0003": {
        "name": "Persistence",
        "techniques": {
            "T1547.001": "Registry Run Keys",
            "T1543.003": "Windows Service",
            "T1053.005": "Scheduled Task",
        },
    },
    "TA0004": {
        "name": "Privilege Escalation",
        "techniques": {
            "T1134": "Access Token Manipulation",
            "T1078.002": "Valid Accounts: Domain",
        },
    },
    "TA0005": {
        "name": "Defense Evasion",
        "techniques": {
            "T1218.011": "Rundll32",
            "T1027": "Obfuscated Files or Information",
            "T1070.004": "Indicator Removal: File Deletion",
        },
    },
    "TA0006": {
        "name": "Credential Access",
        "techniques": {
            "T1003.001": "LSASS Memory",
            "T1558.003": "Kerberoasting",
            "T1110": "Brute Force",
        },
    },
    "TA0007": {
        "name": "Discovery",
        "techniques": {
            "T1482": "Domain Trust Discovery",
            "T1087.002": "Domain Account Discovery",
            "T1016": "System Network Configuration",
            "T1083": "File and Directory Discovery",
        },
    },
    "TA0008": {
        "name": "Lateral Movement",
        "techniques": {
            "T1021.001": "Remote Desktop Protocol",
            "T1021.006": "Windows Remote Management",
            "T1021.002": "SMB/Windows Admin Shares",
        },
    },
    "TA0009": {
        "name": "Collection",
        "techniques": {
            "T1005": "Data from Local System",
        },
    },
    "TA0011": {
        "name": "Command and Control",
        "techniques": {
            "T1071.001": "Web Protocols",
            "T1571": "Non-Standard Port",
        },
    },
    "TA0040": {
        "name": "Impact",
        "techniques": {
            "T1486": "Data Encrypted for Impact",
            "T1490": "Inhibit System Recovery",
            "T1489": "Service Stop",
        },
    },
}


def lookup_technique(technique_id: str) -> dict | None:
    """Look up a MITRE ATT&CK technique by ID.

    Args:
        technique_id: e.g. 'T1059.001'

    Returns:
        Dict with tactic, technique name, and ID, or None.
    """
    for tactic_id, tactic in TACTICS.items():
        if technique_id in tactic["techniques"]:
            return {
                "technique_id": technique_id,
                "technique_name": tactic["techniques"][technique_id],
                "tactic_id": tactic_id,
                "tactic_name": tactic["name"],
            }
    return None


def lookup_tactic(tactic_id: str) -> dict | None:
    """Look up a MITRE ATT&CK tactic and its techniques.

    Args:
        tactic_id: e.g. 'TA0006'

    Returns:
        Dict with tactic info and all techniques, or None.
    """
    tactic = TACTICS.get(tactic_id)
    if not tactic:
        return None
    return {
        "tactic_id": tactic_id,
        "tactic_name": tactic["name"],
        "techniques": [
            {"id": tid, "name": tname}
            for tid, tname in tactic["techniques"].items()
        ],
    }
