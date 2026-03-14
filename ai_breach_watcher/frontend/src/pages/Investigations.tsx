import { getInvestigations } from "../api";
import { useFetch } from "../hooks";

export default function Investigations() {
  const { data, loading, error } = useFetch(getInvestigations);

  if (loading) return <div className="loading">Loading investigations...</div>;
  if (error) return <div className="error">{error}</div>;

  return (
    <div>
      <h2 className="page-title">Investigations</h2>

      <table>
        <thead>
          <tr>
            <th>Status</th>
            <th>Kill Chain Phase</th>
            <th>Tactics</th>
            <th>Narrative</th>
            <th>Created</th>
          </tr>
        </thead>
        <tbody>
          {(data ?? []).map((inv) => (
            <tr key={inv.id}>
              <td><span className={`badge ${inv.status === "open" ? "high" : "low"}`}>{inv.status}</span></td>
              <td>{inv.kill_chain_phase}</td>
              <td>{inv.tactics?.join(", ")}</td>
              <td>{inv.attack_narrative?.slice(0, 120)}</td>
              <td style={{ fontFamily: "monospace", fontSize: "0.8rem" }}>
                {new Date(inv.created_at).toLocaleString()}
              </td>
            </tr>
          ))}
          {(data ?? []).length === 0 && (
            <tr><td colSpan={5} style={{ textAlign: "center", color: "var(--text-secondary)" }}>No investigations</td></tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
