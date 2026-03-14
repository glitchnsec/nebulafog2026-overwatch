import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { getAlerts } from "../api";
import { useFetch } from "../hooks";

export default function Alerts() {
  const [severity, setSeverity] = useState("");
  const navigate = useNavigate();
  const params = severity ? `severity=${severity}` : "";
  const { data, loading, error } = useFetch(() => getAlerts(params), [params]);

  if (loading) return <div className="loading">Loading alerts...</div>;
  if (error) return <div className="error">{error}</div>;

  return (
    <div>
      <h2 className="page-title">Alerts</h2>

      <div style={{ marginBottom: "1rem", display: "flex", gap: "0.5rem" }}>
        {["", "critical", "high", "medium", "low"].map((s) => (
          <button
            key={s}
            className={severity === s ? "primary" : ""}
            onClick={() => setSeverity(s)}
            style={severity !== s ? { background: "var(--bg-card)", color: "var(--text-secondary)", border: "1px solid var(--border)" } : {}}
          >
            {s || "All"}
          </button>
        ))}
      </div>

      <table>
        <thead>
          <tr>
            <th>Severity</th>
            <th>Summary</th>
            <th>Hosts</th>
            <th>Events</th>
            <th>Status</th>
            <th>Time</th>
          </tr>
        </thead>
        <tbody>
          {(data ?? []).map((a) => (
            <tr
              key={a.id}
              className="clickable-row"
              onClick={() => navigate(`/alerts/${a.id}`)}
            >
              <td><span className={`badge ${a.severity}`}>{a.severity}</span></td>
              <td>{a.summary?.slice(0, 120)}{(a.summary?.length ?? 0) > 120 ? "..." : ""}</td>
              <td>{a.hosts?.join(", ")}</td>
              <td>{a.event_count}</td>
              <td><span className={`badge ${a.status === "escalated" ? "high" : "low"}`}>{a.status}</span></td>
              <td style={{ fontFamily: "monospace", fontSize: "0.8rem" }}>
                {new Date(a.created_at).toLocaleString()}
              </td>
            </tr>
          ))}
          {(data ?? []).length === 0 && (
            <tr><td colSpan={6} style={{ textAlign: "center", color: "var(--text-secondary)" }}>No alerts</td></tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
