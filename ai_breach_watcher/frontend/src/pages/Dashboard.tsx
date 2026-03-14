import { getDashboard } from "../api";
import { useFetch, useLiveFeed } from "../hooks";

export default function Dashboard() {
  const { data, loading, error } = useFetch(getDashboard);
  const feed = useLiveFeed();

  if (loading) return <div className="loading">Loading dashboard...</div>;
  if (error) return <div className="error">{error}</div>;
  if (!data) return null;

  const sev = data.alerts_by_severity;

  return (
    <div>
      <h2 className="page-title">Dashboard</h2>

      <div className="card-grid">
        <div className="card">
          <div className="label">Critical Alerts</div>
          <div className="value critical">{sev.critical ?? 0}</div>
        </div>
        <div className="card">
          <div className="label">High Alerts</div>
          <div className="value high">{sev.high ?? 0}</div>
        </div>
        <div className="card">
          <div className="label">Medium Alerts</div>
          <div className="value medium">{sev.medium ?? 0}</div>
        </div>
        <div className="card">
          <div className="label">Open Investigations</div>
          <div className="value">{data.open_investigations}</div>
        </div>
        <div className="card">
          <div className="label">Events (last 5m)</div>
          <div className="value">{data.recent_events_5m}</div>
        </div>
      </div>

      <h3 style={{ marginBottom: "0.75rem" }}>Live Feed</h3>
      <div className="live-feed">
        {feed.length === 0 && (
          <div className="feed-item" style={{ color: "var(--text-secondary)" }}>
            Waiting for events...
          </div>
        )}
        {feed.map((e, i) => (
          <div key={i} className="feed-item">
            <span className="timestamp">{new Date(e.timestamp).toLocaleTimeString()}</span>
            {" "}
            <span className={`badge ${(e.data.severity as string) ?? ""}`}>
              {e.type}
            </span>
            {" "}
            {(e.data.summary as string) ?? JSON.stringify(e.data).slice(0, 120)}
          </div>
        ))}
      </div>
    </div>
  );
}
