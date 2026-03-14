"""TTP Analyst Team — one agent per MITRE ATT&CK tactic, reasoning together."""

from pathlib import Path

from agno.agent import Agent
from agno.models.anthropic import Claude
from agno.team import Team, TeamMode

SKILLS_DIR = Path(__file__).parent.parent.parent / ".claude" / "skills" / "ttp-analysts" / "tactics"


def _load_tactic_instructions(filename: str) -> str:
    """Load tactic instructions from skill file, with fallback."""
    path = SKILLS_DIR / filename
    if path.exists():
        return path.read_text()
    return f"Analyze events for this tactic. Skill file not found: {filename}"


initial_access = Agent(
    name="Initial Access Analyst",
    role="Detect initial compromise vectors (TA0001)",
    model=Claude(id="claude-sonnet-4-5"),
    instructions=_load_tactic_instructions("initial-access.md"),
    markdown=True,
)

execution = Agent(
    name="Execution Analyst",
    role="Detect code execution techniques (TA0002)",
    model=Claude(id="claude-sonnet-4-5"),
    instructions=_load_tactic_instructions("execution.md"),
    markdown=True,
)

persistence = Agent(
    name="Persistence Analyst",
    role="Detect persistence mechanisms (TA0003)",
    model=Claude(id="claude-sonnet-4-5"),
    instructions=_load_tactic_instructions("persistence.md"),
    markdown=True,
)

credential_access = Agent(
    name="Credential Access Analyst",
    role="Detect credential theft techniques (TA0006)",
    model=Claude(id="claude-sonnet-4-5"),
    instructions=_load_tactic_instructions("credential-access.md"),
    markdown=True,
)

lateral_movement = Agent(
    name="Lateral Movement Analyst",
    role="Detect spread across hosts (TA0008)",
    model=Claude(id="claude-sonnet-4-5"),
    instructions=_load_tactic_instructions("lateral-movement.md"),
    markdown=True,
)

impact = Agent(
    name="Impact Analyst",
    role="Detect destructive/disruptive actions (TA0040)",
    model=Claude(id="claude-sonnet-4-5"),
    instructions=_load_tactic_instructions("impact.md"),
    markdown=True,
)

ttp_analyst_team = Team(
    name="TTP Analysis Team",
    mode=TeamMode.coordinate,
    members=[
        initial_access,
        execution,
        persistence,
        credential_access,
        lateral_movement,
        impact,
    ],
    instructions="""\
You lead a team of MITRE ATT&CK tactic specialists. Given raw security
telemetry, distribute events to the relevant specialists based on event type
and content. Synthesize their findings into a coherent attack narrative.

Output a structured assessment as JSON:
{
  "observed_tactics": [{"tactic": "...", "techniques": [...], "evidence": "..."}],
  "kill_chain_phase": "early|mid|late",
  "confidence": "high|medium|low",
  "attack_narrative": "...",
  "predicted_next_actions": [...]
}
""",
    markdown=True,
)
