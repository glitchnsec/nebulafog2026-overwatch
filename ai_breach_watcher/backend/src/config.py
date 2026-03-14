from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    elasticsearch_url: str = "http://localhost:9200"
    anthropic_api_key: str = ""
    poll_interval_seconds: int = 60
    hunt_interval_seconds: int = 300
    log_level: str = "info"

    # ES index names
    winlogbeat_index: str = "winlogbeat-*"
    alerts_index: str = "breach-watcher-alerts"
    investigations_index: str = "breach-watcher-investigations"
    state_index: str = "breach-watcher-state"

    # Skills
    skills_dir: str = ".claude/skills"

    model_config = {"env_prefix": "", "case_sensitive": False}


settings = Settings()
