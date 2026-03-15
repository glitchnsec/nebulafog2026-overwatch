import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter, Routes, Route, NavLink, Outlet } from "react-router-dom";
import Dashboard from "./pages/Dashboard";
import Alerts from "./pages/Alerts";
import Investigations from "./pages/Investigations";
import Skills from "./pages/Skills";
import AgentLogs from "./pages/AgentLogs";
import AlertDetail from "./pages/AlertDetail";
import AgentRunDetail from "./pages/AgentRunDetail";
import About from "./pages/About";
import "./index.css";

function AppShell() {
  return (
    <div className="app">
      <nav className="sidebar">
        <h1 className="logo">Overwatch</h1>
        <NavLink to="/dashboard">Dashboard</NavLink>
        <NavLink to="/alerts">Alerts</NavLink>
        <NavLink to="/investigations">Investigations</NavLink>
        <NavLink to="/skills">Skills</NavLink>
        <NavLink to="/agents">Agent Logs</NavLink>
      </nav>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<About />} />
        <Route element={<AppShell />}>
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/alerts" element={<Alerts />} />
          <Route path="/alerts/:id" element={<AlertDetail />} />
          <Route path="/investigations" element={<Investigations />} />
          <Route path="/skills" element={<Skills />} />
          <Route path="/skills/:name" element={<Skills />} />
          <Route path="/agents" element={<AgentLogs />} />
          <Route path="/agents/:id" element={<AgentRunDetail />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
