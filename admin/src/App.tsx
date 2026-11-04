import { useEffect, useState } from "react";
import { HashRouter, Navigate, NavLink, Outlet, Route, Routes, useNavigate } from "react-router-dom";
import { api, hasToken, setToken, Stats, User } from "./api";
import logo from "./logo.svg";
import Chemicals from "./pages/Chemicals";
import Consultations from "./pages/Consultations";
import Library from "./pages/Library";
import Login from "./pages/Login";
import Overview from "./pages/Overview";
import Security from "./pages/Security";
import Users from "./pages/Users";

function Layout() {
  const nav = useNavigate();
  const [me, setMe] = useState<User | null>(null);
  const [pending, setPending] = useState(0);

  useEffect(() => {
    api.get<User>("/auth/me").then(setMe).catch(() => {});
    api.get<Stats>("/admin/stats?days=1").then((s) => setPending(s.totals.pending_volunteers)).catch(() => {});
  }, []);

  async function logout() {
    await api.post("/auth/logout").catch(() => {});
    setToken(null);
    nav("/login");
  }

  return (
    <div className="shell">
      <aside className="side">
        <div className="brand">
          <img src={logo} width={34} alt="" />
          <div>
            <b>اطمئن</b>
            <small>لوحة الإدارة</small>
          </div>
        </div>
        <nav className="nav">
          <NavLink to="/" end>نظرة عامة</NavLink>
          <NavLink to="/consultations">الاستشارات</NavLink>
          <NavLink to="/volunteers">
            المتطوعون {pending > 0 && <span className="count num">{pending}</span>}
          </NavLink>
          <NavLink to="/users">المستخدمون</NavLink>
          <NavLink to="/chemicals">قاعدة المواد</NavLink>
          <NavLink to="/library">المكتبة</NavLink>
          <NavLink to="/security">سجل الأمان</NavLink>
        </nav>
        <div className="foot">
          {me?.name}
          <br />
          <button onClick={logout}>تسجيل الخروج</button>
        </div>
      </aside>
      <main>
        <Outlet />
      </main>
    </div>
  );
}

function Guard() {
  return hasToken() ? <Layout /> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <HashRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route element={<Guard />}>
          <Route index element={<Overview />} />
          <Route path="consultations" element={<Consultations />} />
          <Route path="volunteers" element={<Users volunteersOnly key="v" />} />
          <Route path="users" element={<Users key="u" />} />
          <Route path="chemicals" element={<Chemicals />} />
          <Route path="library" element={<Library />} />
          <Route path="security" element={<Security />} />
        </Route>
        <Route path="*" element={<Navigate to="/" />} />
      </Routes>
    </HashRouter>
  );
}
