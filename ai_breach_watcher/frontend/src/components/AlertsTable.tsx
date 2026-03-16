import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { getAlerts } from "../api";
import { useFetch } from "../hooks";

const TIME_RANGES = [
  { label: "1h", value: "now-1h" },
  { label: "24h", value: "now-24h" },
  { label: "7d", value: "now-7d" },
  { label: "30d", value: "now-30d" },
  { label: "All", value: "now-10y" },
];

const SEVERITIES = ["", "critical", "high", "medium", "low"];

interface Props {
  /** Default time range */
  defaultTimeFrom?: string;
}

export default function AlertsTable({ defaultTimeFrom = "now-24h" }: Props) {
  const [severity, setSeverity] = useState("");
  const [timeFrom, setTimeFrom] = useState(defaultTimeFrom);
  const navigate = useNavigate();

  const params = [
    severity && `severity=${severity}`,
    `time_from=${timeFrom}`,
  ]
    .filter(Boolean)
    .join("&");

  const { data, loading, error } = useFetch(() => getAlerts(params), [params]);

  return (
    <div>
      <div className="alerts-toolbar">
        <div className="agent-filter-bar">
          {SEVERITIES.map((s) => (
            <button
              key={s}
              className={`agent-filter-btn${severity === s ? " active" : ""}`}
              onClick={() => setSeverity(s)}
            >
              {s || "All"}
            </button>
          ))}
        </div>
        <div className="time-filter-bar">
          {TIME_RANGES.map((t) => (
            <button
              key={t.value}
              className={`time-filter-btn${timeFrom === t.value ? " active" : ""}`}
              onClick={() => setTimeFrom(t.value)}
            >
              {t.label}
            </button>
          ))}
        </div>
      </div>

      {loading && <div className="loading">Loading alerts...</div>}
      {error && <div className="error">{error}</div>}

      {!loading && !error && (
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
                <td data-label="Severity">
                  <span className={`badge ${a.severity}`}>{a.severity}</span>
                </td>
                <td data-label="Summary">
                  {a.summary?.slice(0, 120)}
                  {(a.summary?.length ?? 0) > 120 ? "..." : ""}
                </td>
                <td data-label="Hosts">{a.hosts?.join(", ")}</td>
                <td data-label="Events">{a.event_count}</td>
                <td data-label="Status">
                  <span
                    className={`badge ${a.status === "escalated" ? "high" : "low"}`}
                  >
                    {a.status}
                  </span>
                </td>
                <td data-label="Time" className="mono">
                  {new Date(a.created_at).toLocaleString()}
                </td>
              </tr>
            ))}
            {(data ?? []).length === 0 && (
              <tr>
                <td colSpan={6} className="empty-row">
                  No alerts
                </td>
              </tr>
            )}
          </tbody>
        </table>
      )}
    </div>
  );
}
