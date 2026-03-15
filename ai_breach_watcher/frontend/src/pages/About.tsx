import { useNavigate } from "react-router-dom";

export default function About() {
  const navigate = useNavigate();
  return (
    <div className="about-page">
      {/* ── Hero ── */}
      <div className="hero">
        <h1 className="hero-title">
          The Intuition of an Analyst<br />
          <span className="hero-accent">at the Speed of a Machine</span>
        </h1>
        <p className="hero-subtitle">
          Overwatch monitors your environment around the clock, correlates
          adversary behavior across your kill chain, and surfaces only the threats
          that matter — so your team can focus on response, not triage.
        </p>
        <div className="hero-ctas">
          <button className="demo-btn" onClick={() => navigate("/dashboard")}>
            Open Demo Dashboard
          </button>
          <a className="demo-btn secondary" href="https://github.com/glitchnsec/nebulafog2026-overwatch" target="_blank" rel="noopener noreferrer">
            GitHub
          </a>
        </div>
      </div>

      {/* ── Stat bar ── */}
      <div className="stat-bar">
        <div className="stat-item">
          <span className="stat-number">90%</span>
          <span className="stat-desc">Alert noise eliminated</span>
        </div>
        <div className="stat-divider" />
        <div className="stat-item">
          <span className="stat-number">60s</span>
          <span className="stat-desc">Continuous monitoring cycle</span>
        </div>
        <div className="stat-divider" />
        <div className="stat-item">
          <span className="stat-number">10</span>
          <span className="stat-desc">Specialized AI agents</span>
        </div>
        <div className="stat-divider" />
        <div className="stat-item">
          <span className="stat-number">0</span>
          <span className="stat-desc">Automated actions taken</span>
        </div>
      </div>

      {/* ── Problem ── */}
      <div className="about-section">
        <div className="section-label">The Problem</div>
        <h2 className="about-heading-lg">
          Your SOC is overwhelmed.<br />
          Adversaries are not.
        </h2>
        <div className="about-grid-2">
          <div className="about-card glass">
            <h3>4,000+ alerts per day</h3>
            <p>
              The average enterprise SOC processes thousands of alerts daily.
              Analysts spend 75% of their time on events that turn out to be
              benign. Real attacks slip through because there simply aren't enough
              hours.
            </p>
          </div>
          <div className="about-card glass">
            <h3>Rules can't think in chains</h3>
            <p>
              An individual PowerShell execution isn't suspicious. But PowerShell
              &rarr; credential dump &rarr; lateral move &rarr; data staging is a
              breach in progress. Static rules see atoms. Adversaries operate in chains.
            </p>
          </div>
        </div>
      </div>

      {/* ── Value props ── */}
      <div className="about-section">
        <div className="section-label">Why Overwatch</div>
        <h2 className="about-heading-lg">
          Threat stories, not log lines
        </h2>
        <div className="value-grid">
          <div className="value-card">
            <div className="value-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" width="28" height="28">
                <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <h3>Correlated Attack Narratives</h3>
            <p>
              Overwatch doesn't alert on isolated events. It correlates
              activity across hosts, time, and kill chain phases — then delivers
              a coherent threat narrative your team can act on immediately.
            </p>
          </div>
          <div className="value-card">
            <div className="value-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" width="28" height="28">
                <path d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <h3>Severity Earned, Not Assumed</h3>
            <p>
              Most tools over-alert to avoid missing anything. Overwatch
              assumes benign by default. Severity is only assigned when correlated
              evidence across multiple kill chain phases justifies it.
            </p>
          </div>
          <div className="value-card">
            <div className="value-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" width="28" height="28">
                <path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" strokeLinecap="round" strokeLinejoin="round"/>
                <path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <h3>Full Reasoning Transparency</h3>
            <p>
              Every decision is logged and auditable. Your analysts can see exactly
              why a threat was escalated — or why normal activity was dismissed.
              No black boxes. No unexplainable scores.
            </p>
          </div>
          <div className="value-card">
            <div className="value-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" width="28" height="28">
                <path d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <h3>Your Team Stays in Control</h3>
            <p>
              Agent instructions are editable from the UI with full version history.
              Your analysts tune detection logic in plain English — no code changes,
              no vendor tickets, no waiting for the next release.
            </p>
          </div>
        </div>
      </div>

      {/* ── How it works (simplified) ── */}
      <div className="about-section">
        <div className="section-label">How It Works</div>
        <h2 className="about-heading-lg">
          From raw logs to threat intelligence<br />
          in under five minutes
        </h2>
        <div className="how-flow">
          <div className="how-step">
            <div className="how-number">1</div>
            <div>
              <h3>Learn what's normal</h3>
              <p>
                The system continuously fingerprints event patterns in your
                environment and builds a behavioral baseline. Known-good activity
                is suppressed automatically.
              </p>
            </div>
          </div>
          <div className="how-connector" />
          <div className="how-step">
            <div className="how-number">2</div>
            <div>
              <h3>Flag what's different</h3>
              <p>
                Novel activity is classified by an AI triage agent. Most batches
                are marked normal — no alert, no noise. Only genuinely unusual
                patterns are escalated.
              </p>
            </div>
          </div>
          <div className="how-connector" />
          <div className="how-step">
            <div className="how-number">3</div>
            <div>
              <h3>Hunt for attack chains</h3>
              <p>
                A dedicated hunter correlates suspicious events across a 30-minute
                window and multiple hosts. It looks for adversary behavior patterns —
                not individual indicators.
              </p>
            </div>
          </div>
          <div className="how-connector" />
          <div className="how-step">
            <div className="how-number">4</div>
            <div>
              <h3>Deliver the full story</h3>
              <p>
                When a real threat is found, a team of specialist agents maps it to
                MITRE ATT&CK, builds the attack narrative, and drafts a response
                playbook — ready for your team to review.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* ── Zero automated actions ── */}
      <div className="about-section commitment-section">
        <div className="commitment-card">
          <h2>Recommends. Never executes.</h2>
          <p>
            Overwatch drafts containment and remediation playbooks, but every
            action requires human approval. Your analysts make the final call —
            the AI provides the intelligence to make it fast.
          </p>
        </div>
      </div>

      {/* ── Use cases ── */}
      <div className="about-section">
        <div className="section-label">Use Cases</div>
        <h2 className="about-heading-lg">Built for security teams of every size</h2>
        <div className="about-grid-2">
          <div className="usecase-card">
            <h3>24/7 SOC Augmentation</h3>
            <p>
              Extend your team's coverage without adding headcount. Overwatch
              monitors continuously and only pages when it has a real story to tell.
            </p>
          </div>
          <div className="usecase-card">
            <h3>Adversary Emulation Validation</h3>
            <p>
              Run red team exercises and measure detection coverage in real time.
              The platform works on raw telemetry — no pre-labeled hints — so
              results reflect genuine detection capability.
            </p>
          </div>
          <div className="usecase-card">
            <h3>Incident Investigation</h3>
            <p>
              When an alert fires, the full kill chain analysis and response plan
              are already assembled. Reduce investigation time from hours to minutes.
            </p>
          </div>
          <div className="usecase-card">
            <h3>Compliance & Audit Readiness</h3>
            <p>
              Every agent decision is logged with full reasoning traces.
              Demonstrate continuous monitoring and documented response to auditors
              with a single export.
            </p>
          </div>
        </div>
      </div>

      {/* ── Under the hood (technical, below fold) ── */}
      <div className="about-section">
        <div className="section-label">Under the Hood</div>
        <h2 className="about-heading-lg">
          A coordinated team of AI specialists
        </h2>
        <p className="section-intro">
          Overwatch deploys 10 purpose-built AI agents, each with a defined
          role and strict authority boundaries. No single agent can both detect
          and assign severity — preventing the false-positive inflation that plagues
          conventional AI security tools.
        </p>
        <div className="about-grid-3">
          <div className="agent-card">
            <div className="agent-role triage">Triage</div>
            <p>Classifies events as normal, suspicious, or needs investigation. Never assigns severity.</p>
          </div>
          <div className="agent-card">
            <div className="agent-role hunter">Hunter</div>
            <p>Sole authority to assign severity. Correlates TTP chains across hosts and time windows.</p>
          </div>
          <div className="agent-card">
            <div className="agent-role ttp">TTP Analyst Team</div>
            <p>Six MITRE ATT&CK specialists that collaboratively analyze escalated threats.</p>
          </div>
          <div className="agent-card">
            <div className="agent-role responder">Responder</div>
            <p>Drafts containment and remediation playbooks. Recommends actions — never executes them.</p>
          </div>
        </div>
        <div className="ttp-spread">
          <h3 className="ttp-spread-title">MITRE ATT&CK Coverage</h3>
          <div className="ttp-spread-grid">
            <div className="ttp-card">
              <span className="ttp-id">TA0001</span>
              <span>Initial Access</span>
            </div>
            <div className="ttp-card">
              <span className="ttp-id">TA0002</span>
              <span>Execution</span>
            </div>
            <div className="ttp-card">
              <span className="ttp-id">TA0003</span>
              <span>Persistence</span>
            </div>
            <div className="ttp-card">
              <span className="ttp-id">TA0006</span>
              <span>Credential Access</span>
            </div>
            <div className="ttp-card">
              <span className="ttp-id">TA0008</span>
              <span>Lateral Movement</span>
            </div>
            <div className="ttp-card">
              <span className="ttp-id">TA0040</span>
              <span>Impact</span>
            </div>
          </div>
        </div>
      </div>

      {/* ── Deployment ── */}
      <div className="about-section">
        <div className="section-label">Deployment</div>
        <h2 className="about-heading-lg">Up and running in minutes</h2>
        <div className="deploy-steps">
          <div className="deploy-step">
            <span className="deploy-num">1</span>
            <span>Point to your Elasticsearch instance</span>
          </div>
          <div className="deploy-step">
            <span className="deploy-num">2</span>
            <span>Run a single Docker command</span>
          </div>
          <div className="deploy-step">
            <span className="deploy-num">3</span>
            <span>Agents begin monitoring immediately</span>
          </div>
        </div>
        <p className="deploy-note">
          No infrastructure changes. No log pipeline modifications. No training data required.
        </p>
      </div>

      {/* ── Tech stack (minimal) ── */}
      <div className="about-section tech-stack">
        <div className="tech-pills">
          <span className="tech-pill">Claude AI</span>
          <span className="tech-pill">MITRE ATT&CK</span>
          <span className="tech-pill">Elasticsearch</span>
          <span className="tech-pill">Real-Time WebSocket</span>
          <span className="tech-pill">Docker</span>
          <span className="tech-pill">Git-Versioned Agent Skills</span>
        </div>
      </div>

      {/* ── Final CTA ── */}
      <div className="about-section final-cta">
        <h2>See it in action</h2>
        <p>
          Explore the live dashboard, review real alerts and investigations,
          and see exactly how AI agents reason about threats in your environment.
        </p>
        <button className="demo-btn" onClick={() => navigate("/dashboard")}>
          Open Demo Dashboard
        </button>
      </div>

      <div className="about-footer">
        <p>Overwatch &mdash; NebularFog 2026</p>
      </div>
    </div>
  );
}
