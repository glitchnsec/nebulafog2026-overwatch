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

      <div className="agent-filter-bar">
        {["", "critical", "high", "medium", "low"].map((s) => (
          <button
            key={s}
            className={`agent-filter-btn${severity === s ? " active" : ""}`}
            onClick={() => setSeverity(s)}
          >
            {s || "All"}
          </button>
        ))}
      </div>

      <table className="responsive-table">
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
              <td data-label="Severity"><span className={`badge ${a.severity}`}>{a.severity}</span></td>
              <td data-label="Summary">{a.summary?.slice(0, 120)}{(a.summary?.length ?? 0) > 120 ? "..." : ""}</td>
              <td data-label="Hosts">{a.hosts?.join(", ")}</td>
              <td data-label="Events">{a.event_count}</td>
              <td data-label="Status"><span className={`badge ${a.status === "escalated" ? "high" : "low"}`}>{a.status}</span></td>
              <td data-label="Time" className="mono">{new Date(a.created_at).toLocaleString()}</td>
            </tr>
          ))}
          {(data ?? []).length === 0 && (
            <tr><td colSpan={6} className="empty-row">No alerts</td></tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
