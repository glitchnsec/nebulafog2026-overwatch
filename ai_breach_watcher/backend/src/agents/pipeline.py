"""Breach Analysis Pipeline — Agno Workflow: triage -> TTP team -> responder."""

from pathlib import Path

from agno.agent import Agent
from agno.models.anthropic import Claude
from agno.workflow import Workflow

from src.agents.ttp_team import ttp_analyst_team

SKILLS_DIR = Path(__file__).parent.parent.parent / ".claude" / "skills"


def _load_skill(skill_name: str) -> str:
    """Load a SKILL.md file content."""
    path = SKILLS_DIR / skill_name / "SKILL.md"
    if path.exists():
        content = path.read_text()
        # Strip YAML frontmatter for use as instructions
        if content.startswith("---"):
            parts = content.split("---", 2)
            if len(parts) >= 3:
                return parts[2].strip()
        return content
    return f"Skill not found: {skill_name}"


triage_agent = Agent(
    name="Triage",
    role="SOC Tier 1 — classify and prioritize raw security events",
    model=Claude(id="claude-sonnet-4-5"),
    instructions=_load_skill("triage"),
    markdown=True,
)

hunt_agent = Agent(
    name="Hunter",
    role="Proactive threat hunter — find what detection rules miss",
    model=Claude(id="claude-sonnet-4-5"),
    instructions=_load_skill("hunt"),
    markdown=True,
)

responder_agent = Agent(
    name="Responder",
    role="Recommend containment actions — NEVER execute directly",
    model=Claude(id="claude-sonnet-4-5"),
    instructions=_load_skill("responder"),
    markdown=True,
)

breach_workflow = Workflow(
    name="Breach Analysis Pipeline",
    steps=[
        triage_agent,
        ttp_analyst_team,
        responder_agent,
    ],
)
