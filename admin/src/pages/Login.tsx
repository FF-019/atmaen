import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api, setToken, User } from "../api";
import logo from "../logo.svg";

export default function Login() {
  const nav = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setErr("");
    try {
      const res = await api.post<{ access_token: string; user: User }>("/auth/login", { email, password });
      if (res.user.role !== "admin") {
        setErr("هذه اللوحة لحسابات الإدارة فقط");
        return;
      }
      setToken(res.access_token);
      nav("/");
    } catch {
      setErr("البريد أو كلمة المرور غير صحيحة");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login">
      <div className="art">
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <img src={logo} width={34} alt="" />
          <b>اطمئن</b>
        </div>
        <div>
          <h2>كل دقيقة تُختصر هنا، تُختصر على طفل في مكانٍ ما.</h2>
          <p>لوحة إدارة اطمئن: قاعدة المواد، المتطوعون، والاستشارات في مكان واحد.</p>
        </div>
        <img className="mark" src={logo} alt="" />
      </div>
      <form onSubmit={submit}>
        <h1>دخول الإدارة</h1>
        <label className="field">
          البريد الإلكتروني
          <input className="input ltr" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label className="field">
          كلمة المرور
          <input className="input ltr" type="password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        </label>
        {err && <p className="error">{err}</p>}
        <button className="btn primary" style={{ height: 46, justifyContent: "center" }} disabled={busy}>
          {busy ? "..." : "دخول"}
        </button>
      </form>
    </div>
  );
}
