"""Git-backed skill versioning."""

import os
from pathlib import Path

from git import Repo
from git.exc import InvalidGitRepositoryError

from src.config import settings


def _get_repo() -> Repo:
    """Get or initialize the git repo for skill versioning."""
    repo_path = Path(os.getcwd())
    try:
        return Repo(repo_path)
    except InvalidGitRepositoryError:
        repo = Repo.init(repo_path)
        repo.index.commit("Initial commit for skill versioning")
        return repo


def save_skill_version(skill_name: str, content: str, author: str = "breach-watcher") -> str:
    """Save a skill file and commit the change.

    Returns:
        The commit SHA.
    """
    repo = _get_repo()
    skill_path = Path(settings.skills_dir) / skill_name / "SKILL.md"
    skill_path.parent.mkdir(parents=True, exist_ok=True)
    skill_path.write_text(content)

    repo.index.add([str(skill_path)])
    commit = repo.index.commit(
        f"Update skill: {skill_name}",
        author=f"{author} <{author}@breach-watcher>",
    )
    return commit.hexsha


def get_skill_history(skill_name: str, max_entries: int = 20) -> list[dict]:
    """Get commit history for a skill file.

    Returns:
        List of {sha, message, author, date} dicts.
    """
    repo = _get_repo()
    skill_path = Path(settings.skills_dir) / skill_name / "SKILL.md"

    if not skill_path.exists():
        return []

    commits = list(repo.iter_commits(paths=str(skill_path), max_count=max_entries))
    return [
        {
            "sha": c.hexsha,
            "message": c.message.strip(),
            "author": str(c.author),
            "date": c.committed_datetime.isoformat(),
        }
        for c in commits
    ]


def get_skill_at_version(skill_name: str, sha: str) -> str | None:
    """Get the content of a skill file at a specific commit."""
    repo = _get_repo()
    skill_path = Path(settings.skills_dir) / skill_name / "SKILL.md"

    try:
        blob = repo.commit(sha).tree / str(skill_path)
        return blob.data_stream.read().decode("utf-8")
    except Exception:
        return None
