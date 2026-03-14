import { useParams, useNavigate } from "react-router-dom";
import ReactMarkdown from "react-markdown";
import { getAgentRun } from "../api";
import { useFetch } from "../hooks";

export default function AgentRunDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data: run, loading, error } = useFetch(
    () => getAgentRun(id!),
    [id]
  );

  if (loading) return <div className="loading">Loading agent run...</div>;
  if (error) return <div className="error">{error}</div>;
  if (!run) return <div className="error">Agent run not found</div>;

  const duration =
    run.started_at && run.completed_at
      ? Math.round(
          (new Date(run.completed_at).getTime() -
            new Date(run.started_at).getTime()) /
            1000
        )
      : null;

  return (
    <div>
      <button
        onClick={() => navigate("/agents")}
        style={{
          background: "none",
          color: "var(--text-secondary)",
          marginBottom: "1rem",
          padding: "0.25rem 0",
          fontSize: "0.85rem",
        }}
      >
        &larr; Back to Agent Logs
      </button>

      <div style={{ display: "flex", alignItems: "center", gap: "1rem", marginBottom: "1.5rem" }}>
        <h2 className="page-title" style={{ marginBottom: 0 }}>
          {run.agent_name}
        </h2>
        <span
          className={`badge ${
            run.status === "completed"
              ? "low"
              : run.status === "running"
              ? "medium"
              : "high"
          }`}
        >
          {run.status}
        </span>
      </div>

      <div className="card" style={{ marginBottom: "1.5rem" }}>
        <div className="detail-grid">
          <div>
            <span className="detail-label">Started</span>
            <span className="detail-value" style={{ fontFamily: "monospace", fontSize: "0.85rem" }}>
              {new Date(run.started_at).toLocaleString()}
            </span>
          </div>
          {run.completed_at && (
            <div>
              <span className="detail-label">Completed</span>
              <span className="detail-value" style={{ fontFamily: "monospace", fontSize: "0.85rem" }}>
                {new Date(run.completed_at).toLocaleString()}
              </span>
            </div>
          )}
          {duration !== null && (
            <div>
              <span className="detail-label">Duration</span>
              <span className="detail-value">{duration}s</span>
            </div>
          )}
          <div>
            <span className="detail-label">Events Analyzed</span>
            <span className="detail-value">{run.event_count ?? "—"}</span>
          </div>
        </div>
      </div>

      {run.prompt_preview && (
        <div className="card" style={{ marginBottom: "1.5rem" }}>
          <h3 className="section-title">Prompt (preview)</h3>
          <pre className="code-block">{run.prompt_preview}</pre>
        </div>
      )}

      {run.reasoning_trace && (
        <div className="card">
          <h3 className="section-title">Agent Output</h3>
          <div className="markdown-body">
            <ReactMarkdown>{run.reasoning_trace}</ReactMarkdown>
          </div>
        </div>
      )}
    </div>
  );
}
