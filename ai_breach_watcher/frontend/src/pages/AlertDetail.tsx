import { useParams, useNavigate } from "react-router-dom";
import ReactMarkdown from "react-markdown";
import { getAlert, getInvestigationByAlert } from "../api";
import { useFetch } from "../hooks";
import type { Alert, Investigation } from "../api";

const FLOW_STEPS = ["Triage", "TTP Analysis", "Response Plan"] as const;

function stepStatus(
  alert: Alert | null,
  inv: Investigation | null,
  step: string
): "completed" | "active" | "pending" | "skipped" {
  if (!alert) return "pending";
  if (step === "Triage") return alert.triage_output ? "completed" : "active";
  if (!alert.triage_output) return "pending";
  const escalated = alert.status === "escalated";
  if (!escalated) return "skipped";
  if (step === "TTP Analysis") return inv?.ttp_analysis ? "completed" : "active";
  if (step === "Response Plan") return inv?.response_plan ? "completed" : "pending";
  return "pending";
}

function stepContent(
  alert: Alert | null,
  inv: Investigation | null,
  step: string
): string | undefined {
  if (step === "Triage") return alert?.triage_output;
  if (step === "TTP Analysis") return inv?.ttp_analysis;
  if (step === "Response Plan") return inv?.response_plan;
  return undefined;
}

export default function AlertDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data: alert, loading, error } = useFetch(
    () => getAlert(id!),
    [id]
  );
  const { data: investigation } = useFetch(
    () => getInvestigationByAlert(id!),
    [id]
  );

  if (loading) return <div className="loading">Loading alert...</div>;
  if (error) return <div className="error">{error}</div>;
  if (!alert) return <div className="error">Alert not found</div>;

  const isHunt = alert.status === "hunt_finding";

  return (
    <div>
      <button
        onClick={() => navigate("/alerts")}
        style={{
          background: "none",
          color: "var(--text-secondary)",
          marginBottom: "1rem",
          padding: "0.25rem 0",
          fontSize: "0.85rem",
        }}
      >
        &larr; Back to Alerts
      </button>

      <div style={{ display: "flex", alignItems: "center", gap: "1rem", marginBottom: "1.5rem" }}>
        <h2 className="page-title" style={{ marginBottom: 0 }}>
          Alert Detail
        </h2>
        <span className={`badge ${alert.severity}`}>{alert.severity}</span>
        <span className={`badge ${alert.status === "escalated" ? "high" : "low"}`}>
          {alert.status}
        </span>
      </div>

      {/* Alert metadata */}
      <div className="card" style={{ marginBottom: "1.5rem" }}>
        <div className="detail-grid">
          <div>
            <span className="detail-label">Hosts</span>
            <span className="detail-value">{alert.hosts?.join(", ") || "—"}</span>
          </div>
          <div>
            <span className="detail-label">Event Count</span>
            <span className="detail-value">{alert.event_count}</span>
          </div>
          <div>
            <span className="detail-label">Created</span>
            <span className="detail-value" style={{ fontFamily: "monospace", fontSize: "0.85rem" }}>
              {new Date(alert.created_at).toLocaleString()}
            </span>
          </div>
          <div>
            <span className="detail-label">Summary</span>
            <span className="detail-value">{alert.summary}</span>
          </div>
        </div>
      </div>

      {/* Hunt finding — single output */}
      {isHunt && alert.hunt_output && (
        <div className="card" style={{ marginBottom: "1.5rem" }}>
          <h3 className="section-title">Hunt Finding</h3>
          <div className="markdown-body">
            <ReactMarkdown>{alert.hunt_output}</ReactMarkdown>
          </div>
        </div>
      )}

      {/* Agent flow pipeline (non-hunt alerts) */}
      {!isHunt && (
        <>
          <h3 style={{ marginBottom: "1rem" }}>Agent Pipeline</h3>
          <div className="agent-flow">
            {FLOW_STEPS.map((step, i) => {
              const status = stepStatus(alert, investigation, step);
              const content = stepContent(alert, investigation, step);
              return (
                <div key={step} className="flow-step-wrapper">
                  {i > 0 && (
                    <div className={`flow-connector ${status === "skipped" ? "skipped" : ""}`}>
                      <div className="connector-line" />
                      <div className="connector-arrow" />
                    </div>
                  )}
                  <div className={`flow-step ${status}`}>
                    <div className="flow-step-header">
                      <span className={`flow-status-dot ${status}`} />
                      <span className="flow-step-name">{step}</span>
                      <span className={`flow-status-label ${status}`}>
                        {status === "skipped" ? "not escalated" : status}
                      </span>
                    </div>
                    {content && (
                      <div className="flow-step-content markdown-body">
                        <ReactMarkdown>{content}</ReactMarkdown>
                      </div>
                    )}
                    {status === "skipped" && (
                      <div className="flow-step-content" style={{ color: "var(--text-secondary)", fontStyle: "italic" }}>
                        Skipped — severity below escalation threshold
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>

          {/* Investigation details */}
          {investigation && (
            <div className="card" style={{ marginTop: "1.5rem" }}>
              <h3 className="section-title">Investigation</h3>
              <div className="detail-grid">
                <div>
                  <span className="detail-label">Kill Chain Phase</span>
                  <span className="detail-value">{investigation.kill_chain_phase || "—"}</span>
                </div>
                <div>
                  <span className="detail-label">Tactics</span>
                  <span className="detail-value">
                    {investigation.tactics?.length
                      ? investigation.tactics.map((t) => (
                          <span key={t} className="tactic-tag">{t}</span>
                        ))
                      : "—"}
                  </span>
                </div>
              </div>
              {investigation.attack_narrative && (
                <div style={{ marginTop: "1rem" }}>
                  <span className="detail-label">Attack Narrative</span>
                  <div className="markdown-body" style={{ marginTop: "0.5rem" }}>
                    <ReactMarkdown>{investigation.attack_narrative}</ReactMarkdown>
                  </div>
                </div>
              )}
            </div>
          )}
        </>
      )}
    </div>
  );
}
