"""Skills API — CRUD with git-backed versioning."""

from pathlib import Path

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from src.config import settings
from src.state.versioning import (
    save_skill_version,
    get_skill_history,
    get_skill_at_version,
)

router = APIRouter()


class SkillUpdate(BaseModel):
    content: str
    author: str = "operator"


@router.get("")
async def list_skills():
    """List all skills with their metadata."""
    skills_dir = Path(settings.skills_dir)
    if not skills_dir.exists():
        return []

    result = []
    for skill_path in sorted(skills_dir.iterdir()):
        skill_md = skill_path / "SKILL.md"
        if skill_md.exists():
            content = skill_md.read_text()
            name, description = _parse_frontmatter(content)
            result.append({
                "name": skill_path.name,
                "display_name": name,
                "description": description,
                "path": str(skill_md),
            })
    return result


@router.get("/{skill_name}")
async def get_skill(skill_name: str):
    """Get a skill's content and metadata."""
    skill_md = Path(settings.skills_dir) / skill_name / "SKILL.md"
    if not skill_md.exists():
        raise HTTPException(status_code=404, detail=f"Skill '{skill_name}' not found")

    content = skill_md.read_text()
    name, description = _parse_frontmatter(content)

    # List bundled files (Level 3 resources)
    skill_dir = skill_md.parent
    bundled_files = [
        f.name for f in skill_dir.iterdir()
        if f.is_file() and f.name != "SKILL.md"
    ]

    return {
        "name": skill_name,
        "display_name": name,
        "description": description,
        "content": content,
        "bundled_files": bundled_files,
    }


@router.put("/{skill_name}")
async def update_skill(skill_name: str, update: SkillUpdate):
    """Update a skill and commit the change."""
    sha = save_skill_version(skill_name, update.content, update.author)
    return {"name": skill_name, "commit": sha}


@router.get("/{skill_name}/history")
async def skill_history(skill_name: str):
    """Get version history for a skill."""
    return get_skill_history(skill_name)


@router.get("/{skill_name}/version/{sha}")
async def skill_at_version(skill_name: str, sha: str):
    """Get a skill's content at a specific version."""
    content = get_skill_at_version(skill_name, sha)
    if content is None:
        raise HTTPException(status_code=404, detail="Version not found")
    return {"name": skill_name, "sha": sha, "content": content}


@router.get("/{skill_name}/files/{filename}")
async def get_skill_file(skill_name: str, filename: str):
    """Read a bundled resource file from a skill."""
    file_path = Path(settings.skills_dir) / skill_name / filename
    if not file_path.exists() or not file_path.is_file():
        raise HTTPException(status_code=404, detail="File not found")
    return {"name": filename, "content": file_path.read_text()}


def _parse_frontmatter(content: str) -> tuple[str, str]:
    """Extract name and description from YAML frontmatter."""
    name = ""
    description = ""
    if content.startswith("---"):
        parts = content.split("---", 2)
        if len(parts) >= 3:
            for line in parts[1].strip().splitlines():
                if line.startswith("name:"):
                    name = line.split(":", 1)[1].strip()
                elif line.startswith("description:"):
                    description = line.split(":", 1)[1].strip()
    return name, description
