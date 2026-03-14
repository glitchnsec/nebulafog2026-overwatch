const BASE = "/api";

async function fetchJson<T>(url: string, init?: RequestInit): Promise<T> {
  const resp = await fetch(`${BASE}${url}`, {
    headers: { "Content-Type": "application/json" },
    ...init,
  });
  if (!resp.ok) throw new Error(`${resp.status} ${resp.statusText}`);
  return resp.json();
}

// Dashboard
export const getDashboard = () => fetchJson<DashboardData>("/dashboard");

// Alerts
export const getAlerts = (params?: string) =>
  fetchJson<Alert[]>(`/alerts${params ? `?${params}` : ""}`);
export const getAlert = (id: string) => fetchJson<Alert>(`/alerts/${id}`);
export const updateAlert = (id: string, body: Partial<Alert>) =>
  fetchJson(`/alerts/${id}`, { method: "PUT", body: JSON.stringify(body) });

// Investigations
export const getInvestigations = () => fetchJson<Investigation[]>("/investigations");
export const getInvestigation = (id: string) =>
  fetchJson<Investigation>(`/investigations/${id}`);

// Skills
export const getSkills = () => fetchJson<SkillSummary[]>("/skills");
export const getSkill = (name: string) => fetchJson<SkillDetail>(`/skills/${name}`);
export const updateSkill = (name: string, content: string, author = "operator") =>
  fetchJson(`/skills/${name}`, {
    method: "PUT",
    body: JSON.stringify({ content, author }),
  });
export const getSkillHistory = (name: string) =>
  fetchJson<VersionEntry[]>(`/skills/${name}/history`);
export const getSkillAtVersion = (name: string, sha: string) =>
  fetchJson<{ content: string }>(`/skills/${name}/version/${sha}`);

// Agent logs
export const getAgentRuns = (agent?: string) =>
  fetchJson<AgentRun[]>(`/agents${agent ? `?agent_name=${agent}` : ""}`);
export const getAgentRun = (id: string) => fetchJson<AgentRun>(`/agents/${id}`);

// Types
export interface DashboardData {
  alerts_by_severity: Record<string, number>;
  alerts_by_status: Record<string, number>;
  open_investigations: number;
  recent_events_5m: number;
}

export interface Alert {
  id: string;
  severity: string;
  status: string;
  summary: string;
  hosts: string[];
  event_count: number;
  created_at: string;
}

export interface Investigation {
  id: string;
  status: string;
  attack_narrative: string;
  kill_chain_phase: string;
  tactics: string[];
  created_at: string;
}

export interface SkillSummary {
  name: string;
  display_name: string;
  description: string;
}

export interface SkillDetail extends SkillSummary {
  content: string;
  bundled_files: string[];
}

export interface VersionEntry {
  sha: string;
  message: string;
  author: string;
  date: string;
}

export interface AgentRun {
  id: string;
  agent_name: string;
  status: string;
  started_at: string;
  completed_at?: string;
  event_count?: number;
  result_summary?: string;
  reasoning_trace?: string;
}
