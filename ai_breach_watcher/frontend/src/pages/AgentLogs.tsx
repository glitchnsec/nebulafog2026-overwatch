import { useState } from "react";
import { getAgentRuns } from "../api";
import { useFetch } from "../hooks";

const AGENTS = ["", "Triage", "TTP Analysis Team", "Hunter", "Responder"];

export default function AgentLogs() {
  const [agent, setAgent] = useState("");
  const { data, loading, error } = useFetch(
    () => getAgentRuns(agent || undefined),
    [agent]
  );

  if (loading) return <div className="loading">Loading agent logs...</div>;
  if (error) return <div className="error">{error}</div>;

  return (
    <div>
      <h2 className="page-title">Agent Logs</h2>

      <div style={{ marginBottom: "1rem", display: "flex", gap: "0.5rem" }}>
        {AGENTS.map((a) => (
          <button
            key={a}
            className={agent === a ? "primary" : ""}
            onClick={() => setAgent(a)}
            style={agent !== a ? { background: "var(--bg-card)", color: "var(--text-secondary)", border: "1px solid var(--border)" } : {}}
          >
            {a || "All"}
          </button>
        ))}
      </div>

      <table>
        <thead>
          <tr>
            <th>Agent</th>
            <th>Status</th>
            <th>Events</th>
            <th>Summary</th>
            <th>Started</th>
          </tr>
        </thead>
        <tbody>
          {(data ?? []).map((run) => (
            <tr key={run.id}>
              <td>{run.agent_name}</td>
              <td>
                <span className={`badge ${run.status === "completed" ? "low" : run.status === "running" ? "medium" : "high"}`}>
                  {run.status}
                </span>
              </td>
              <td>{run.event_count ?? "-"}</td>
              <td>{run.result_summary?.slice(0, 100) ?? "-"}</td>
              <td style={{ fontFamily: "monospace", fontSize: "0.8rem" }}>
                {new Date(run.started_at).toLocaleString()}
              </td>
            </tr>
          ))}
          {(data ?? []).length === 0 && (
            <tr><td colSpan={5} style={{ textAlign: "center", color: "var(--text-secondary)" }}>No agent runs</td></tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
