import { useState } from "react";
import { api, Audit } from "../api";
import { fmtDate, PageHead, useLoad } from "../components/ui";

const actions: Record<string, string> = {
  login: "تسجيل دخول",
  login_failed: "محاولة دخول فاشلة",
  logout: "تسجيل خروج",
  register: "تسجيل حساب",
  password_changed: "تغيير كلمة المرور",
  user_disabled: "تعطيل مستخدم",
  user_enabled: "تفعيل مستخدم",
  volunteer_verified: "توثيق متطوع",
  volunteer_unverified: "إلغاء توثيق",
  chemical_created: "إضافة مادة",
  chemical_updated: "تعديل مادة",
  chemical_deleted: "حذف مادة",
};

export default function Security() {
  const [action, setAction] = useState("");
  const { data } = useLoad(() => api.get<Audit[]>(`/admin/audit${action ? `?action=${action}` : ""}`), [action]);
  const failed = data?.filter((a) => a.action === "login_failed").length ?? 0;

  return (
    <>
      <PageHead title="سجل الأمان" sub="كل عملية حساسة تُسجَّل مع المستخدم وعنوان IP." />
      <div className="toolbar">
        <select className="input" style={{ maxWidth: 240 }} value={action} onChange={(e) => setAction(e.target.value)}>
          <option value="">كل العمليات</option>
          {Object.entries(actions).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
        </select>
        {failed > 5 && !action && <span className="tag critical">{failed} محاولة دخول فاشلة مؤخراً</span>}
      </div>
      <div className="card">
        <table className="table">
          <thead>
            <tr><th>الوقت</th><th>العملية</th><th>المستخدم</th><th>التفاصيل</th><th>IP</th></tr>
          </thead>
          <tbody>
            {data?.map((a) => (
              <tr key={a.id}>
                <td className="muted">{fmtDate(a.created_at)}</td>
                <td>
                  <span className={`tag ${a.action === "login_failed" ? "critical" : a.action.startsWith("chemical") ? "brand" : "neutral"}`}>
                    {actions[a.action] ?? a.action}
                  </span>
                </td>
                <td className="num">{a.user_id ?? "—"}</td>
                <td className="ltr muted" style={{ textAlign: "right", fontSize: 13 }}>{a.detail}</td>
                <td className="ltr num faint" style={{ textAlign: "right", fontSize: 13 }}>{a.ip}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
