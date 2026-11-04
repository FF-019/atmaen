import { useState } from "react";
import { api, User } from "../api";
import { fmtDate, PageHead, useLoad } from "../components/ui";

const roleLabel = { parent: "ولي أمر", volunteer: "متطوع", admin: "مدير" } as const;

export default function Users({ volunteersOnly = false }: { volunteersOnly?: boolean }) {
  const [q, setQ] = useState("");
  const [role, setRole] = useState(volunteersOnly ? "volunteer" : "");
  const [pending, setPending] = useState(volunteersOnly);

  const params = new URLSearchParams();
  if (role) params.set("role", role);
  if (pending) params.set("pending", "true");
  if (q.trim()) params.set("q", q.trim());

  const { data, error, reload } = useLoad(() => api.get<User[]>(`/admin/users?${params}`), [role, pending, q]);

  async function update(u: User, body: Partial<Pick<User, "is_active" | "is_verified">>) {
    try {
      await api.patch(`/admin/users/${u.id}`, body);
      reload();
    } catch (e) {
      alert((e as Error).message);
    }
  }

  return (
    <>
      <PageHead
        title={volunteersOnly ? "المتطوعون" : "المستخدمون"}
        sub={volunteersOnly ? "راجع بيانات المتطوع المهنية قبل التوثيق" : "تعطيل حساب يوقف دخوله فوراً"}
      />

      <div className="toolbar">
        <input className="input" placeholder="بحث بالاسم أو البريد" value={q} onChange={(e) => setQ(e.target.value)} />
        {volunteersOnly ? (
          <div className="seg">
            <button className={pending ? "on" : ""} onClick={() => setPending(true)}>بانتظار التحقق</button>
            <button className={!pending ? "on" : ""} onClick={() => setPending(false)}>الكل</button>
          </div>
        ) : (
          <div className="seg">
            {[["", "الكل"], ["parent", "أولياء الأمور"], ["volunteer", "المتطوعون"], ["admin", "الإدارة"]].map(([k, l]) => (
              <button key={k} className={role === k ? "on" : ""} onClick={() => setRole(k)}>
                {l}
              </button>
            ))}
          </div>
        )}
      </div>

      {error && <p className="error">{error}</p>}
      <div className="card">
        {!data ? (
          <div className="empty">جاري التحميل...</div>
        ) : data.length === 0 ? (
          <div className="empty">{pending ? "لا يوجد متطوعون بانتظار التحقق" : "لا نتائج"}</div>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>الاسم</th>
                <th>البريد</th>
                {volunteersOnly ? <th>التخصص والجهة</th> : <th>الدور</th>}
                <th>التسجيل</th>
                <th>الحالة</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {data.map((u) => (
                <tr key={u.id}>
                  <td style={{ fontWeight: 600 }}>{u.name}</td>
                  <td className="ltr muted" style={{ textAlign: "right" }}>{u.email}</td>
                  {volunteersOnly ? (
                    <td>
                      {u.specialty}
                      <div className="faint" style={{ fontSize: 12.5 }}>{u.institution}</div>
                    </td>
                  ) : (
                    <td>{roleLabel[u.role]}</td>
                  )}
                  <td className="muted">{fmtDate(u.created_at, false)}</td>
                  <td>
                    {!u.is_active ? (
                      <span className="tag critical">معطّل</span>
                    ) : u.role === "volunteer" ? (
                      u.is_verified ? <span className="tag low">موثّق</span> : <span className="tag moderate">بانتظار التحقق</span>
                    ) : (
                      <span className="tag neutral">نشط</span>
                    )}
                  </td>
                  <td className="actions">
                    {u.role === "volunteer" && u.is_active && (
                      <button className="btn small" onClick={() => update(u, { is_verified: !u.is_verified })}>
                        {u.is_verified ? "إلغاء التوثيق" : "توثيق"}
                      </button>
                    )}{" "}
                    {u.role !== "admin" && (
                      <button className={`btn small ${u.is_active ? "danger" : ""}`} onClick={() => update(u, { is_active: !u.is_active })}>
                        {u.is_active ? "تعطيل" : "تفعيل"}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
