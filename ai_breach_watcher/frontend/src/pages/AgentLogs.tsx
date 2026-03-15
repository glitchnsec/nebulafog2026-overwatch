import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { getAgentRuns } from "../api";
import { useFetch } from "../hooks";

const AGENTS = ["", "Triage", "TTP Analysis Team", "Hunter", "Responder"];

export default function AgentLogs() {
  const [agent, setAgent] = useState("");
  const navigate = useNavigate();
  const { data, loading, error } = useFetch(
    () => getAgentRuns(agent || undefined),
    [agent]
  );

  if (loading) return <div className="loading">Loading agent logs...</div>;
  if (error) return <div className="error">{error}</div>;

  return (
    <div>
      <h2 className="page-title">Agent Logs</h2>

      <div className="agent-filter-bar">
        {AGENTS.map((a) => (
          <button
            key={a}
            className={`agent-filter-btn${agent === a ? " active" : ""}`}
            onClick={() => setAgent(a)}
          >
            {a || "All"}
          </button>
        ))}
      </div>

      <table className="responsive-table">
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
            <tr
              key={run.id}
              className="clickable-row"
              onClick={() => navigate(`/agents/${run.id}`)}
            >
              <td data-label="Agent">{run.agent_name}</td>
              <td data-label="Status">
                <span className={`badge ${run.status === "completed" ? "low" : run.status === "running" ? "medium" : "high"}`}>
                  {run.status}
                </span>
              </td>
              <td data-label="Events">{run.event_count ?? "-"}</td>
              <td data-label="Summary">{run.result_summary?.slice(0, 100) ?? "-"}{(run.result_summary?.length ?? 0) > 100 ? "..." : ""}</td>
              <td data-label="Started" className="mono">{new Date(run.started_at).toLocaleString()}</td>
            </tr>
          ))}
          {(data ?? []).length === 0 && (
            <tr><td colSpan={5} className="empty-row">No agent runs</td></tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
