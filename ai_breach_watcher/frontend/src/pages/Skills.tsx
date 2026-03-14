import { useState, useEffect } from "react";
import { useParams } from "react-router-dom";
import {
  getSkills,
  getSkill,
  updateSkill,
  getSkillHistory,
  type SkillSummary,
  type SkillDetail,
  type VersionEntry,
} from "../api";
import { useFetch } from "../hooks";

export default function Skills() {
  const { name: routeName } = useParams();
  const { data: skills, loading } = useFetch(getSkills);
  const [selected, setSelected] = useState<string | null>(routeName ?? null);
  const [detail, setDetail] = useState<SkillDetail | null>(null);
  const [history, setHistory] = useState<VersionEntry[]>([]);
  const [content, setContent] = useState("");
  const [saving, setSaving] = useState(false);
  const [saveMsg, setSaveMsg] = useState("");

  useEffect(() => {
    if (selected) {
      getSkill(selected).then((d) => {
        setDetail(d);
        setContent(d.content);
      });
      getSkillHistory(selected).then(setHistory);
    }
  }, [selected]);

  const handleSave = async () => {
    if (!selected) return;
    setSaving(true);
    setSaveMsg("");
    try {
      const resp = await updateSkill(selected, content);
      setSaveMsg(`Saved (${(resp as { commit: string }).commit.slice(0, 7)})`);
      getSkillHistory(selected).then(setHistory);
    } catch (e) {
      setSaveMsg(`Error: ${(e as Error).message}`);
    }
    setSaving(false);
  };

  if (loading) return <div className="loading">Loading skills...</div>;

  return (
    <div>
      <h2 className="page-title">Skills Editor</h2>

      <div className="skill-editor">
        <div className="skill-list">
          {(skills ?? []).map((s: SkillSummary) => (
            <div
              key={s.name}
              className={`skill-list-item ${selected === s.name ? "active" : ""}`}
              onClick={() => setSelected(s.name)}
            >
              <strong>{s.display_name || s.name}</strong>
              <div style={{ fontSize: "0.75rem", color: "var(--text-secondary)", marginTop: "0.2rem" }}>
                {s.description?.slice(0, 60)}
              </div>
            </div>
          ))}
        </div>

        <div className="editor-pane">
          {detail ? (
            <>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.75rem" }}>
                <h3>{detail.display_name || detail.name}</h3>
                <div style={{ display: "flex", gap: "0.5rem", alignItems: "center" }}>
                  {saveMsg && <span style={{ fontSize: "0.8rem", color: "var(--accent-green)" }}>{saveMsg}</span>}
                  <button className="primary" onClick={handleSave} disabled={saving}>
                    {saving ? "Saving..." : "Save & Version"}
                  </button>
                </div>
              </div>

              {detail.bundled_files.length > 0 && (
                <div style={{ fontSize: "0.8rem", color: "var(--text-secondary)", marginBottom: "0.5rem" }}>
                  Bundled: {detail.bundled_files.join(", ")}
                </div>
              )}

              <textarea
                value={content}
                onChange={(e) => setContent(e.target.value)}
                spellCheck={false}
              />

              {history.length > 0 && (
                <div className="version-history">
                  <h4 style={{ marginBottom: "0.5rem" }}>Version History</h4>
                  {history.map((v) => (
                    <div key={v.sha} className="version-item">
                      <span className="sha">{v.sha.slice(0, 7)}</span>
                      <span>{v.message}</span>
                      <span>{new Date(v.date).toLocaleDateString()}</span>
                    </div>
                  ))}
                </div>
              )}
            </>
          ) : (
            <div style={{ color: "var(--text-secondary)", padding: "2rem", textAlign: "center" }}>
              Select a skill to edit
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
