import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter, Routes, Route, NavLink } from "react-router-dom";
import Dashboard from "./pages/Dashboard";
import Alerts from "./pages/Alerts";
import Investigations from "./pages/Investigations";
import Skills from "./pages/Skills";
import AgentLogs from "./pages/AgentLogs";
import "./index.css";

function App() {
  return (
    <BrowserRouter>
      <div className="app">
        <nav className="sidebar">
          <h1 className="logo">Breach Watcher</h1>
          <NavLink to="/">Dashboard</NavLink>
          <NavLink to="/alerts">Alerts</NavLink>
          <NavLink to="/investigations">Investigations</NavLink>
          <NavLink to="/skills">Skills</NavLink>
          <NavLink to="/agents">Agent Logs</NavLink>
        </nav>
        <main className="content">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/alerts" element={<Alerts />} />
            <Route path="/investigations" element={<Investigations />} />
            <Route path="/skills" element={<Skills />} />
            <Route path="/skills/:name" element={<Skills />} />
            <Route path="/agents" element={<AgentLogs />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  );
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
