---
name: ttp-analyst-team
description: >
  Team of MITRE ATT&CK tactic specialists that collaboratively analyze
  raw security telemetry. Each member specializes in one tactic. The team
  leader synthesizes findings into a coherent attack narrative.
---

# TTP Analysis Team

This team consists of specialists for each MITRE ATT&CK tactic. When given
raw security events, the team leader distributes relevant events to each
specialist based on event content, then synthesizes their findings.

## Team Members
- Initial Access Analyst (TA0001)
- Execution Analyst (TA0002)
- Persistence Analyst (TA0003)
- Credential Access Analyst (TA0006)
- Lateral Movement Analyst (TA0008)
- Impact Analyst (TA0040)

## Coordination Protocol
1. Leader reviews the event batch and identifies which tactics may be relevant
2. Events are distributed to the appropriate specialists
3. Each specialist analyzes their subset independently
4. Leader synthesizes findings into a unified attack narrative
5. Identifies kill chain phase and predicts next adversary actions

See individual tactic files in `tactics/` for per-specialist instructions.
