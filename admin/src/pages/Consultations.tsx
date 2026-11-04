import { useEffect, useState } from "react";
import { api, Consultation } from "../api";
import { fmtDate, PageHead, Status, useLoad } from "../components/ui";

export default function Consultations() {
  const [status, setStatus] = useState("");
  const { data, reload } = useLoad(
    () => api.get<Consultation[]>(`/admin/consultations${status ? `?status=${status}` : ""}`),
    [status],
  );

  // live-ish: refresh every 15s so pending requests show up
  useEffect(() => {
    const t = setInterval(reload, 15000);
    return () => clearInterval(t);
  }, [reload]);

  const pending = data?.filter((c) => c.status === "pending").length ?? 0;

  return (
    <>
      <PageHead title="الاستشارات" sub="متابعة الطلبات بين أولياء الأمور والمتطوعين. المحادثات نفسها لا تظهر هنا حفاظاً على الخصوصية." />

      <div className="toolbar">
        <div className="seg">
          {[["", "الكل"], ["pending", "بانتظار متطوع"], ["active", "جارية"], ["completed", "مكتملة"], ["cancelled", "ملغاة"]].map(([k, l]) => (
            <button key={k} className={status === k ? "on" : ""} onClick={() => setStatus(k)}>
              {l}
            </button>
          ))}
        </div>
        {pending > 0 && <span className="tag moderate">{pending} طلب ينتظر الآن</span>}
      </div>

      <div className="card">
        {!data ? (
          <div className="empty">جاري التحميل...</div>
        ) : data.length === 0 ? (
          <div className="empty">لا توجد استشارات</div>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>#</th>
                <th>ولي الأمر</th>
                <th>المتطوع</th>
                <th>الطلب</th>
                <th>الانتظار</th>
                <th>المدة</th>
                <th>التقييم</th>
                <th>الحالة</th>
              </tr>
            </thead>
            <tbody>
              {data.map((c) => {
                const wait =
                  c.start_time && c.created_at
                    ? Math.round((new Date(c.start_time).getTime() - new Date(c.created_at).getTime()) / 6000) / 10
                    : null;
                return (
                  <tr key={c.id}>
                    <td className="num faint">{c.id}</td>
                    <td>{c.parent?.name ?? "—"}</td>
                    <td>
                      {c.volunteer ? (
                        <>
                          {c.volunteer.name}
                          <div className="faint" style={{ fontSize: 12.5 }}>{c.volunteer.specialty}</div>
                        </>
                      ) : (
                        <span className="faint">لم يُقبل بعد</span>
                      )}
                    </td>
                    <td className="muted">{fmtDate(c.created_at)}</td>
                    <td className="num">{wait === null ? "—" : `${wait} د`}</td>
                    <td className="num">{c.duration_minutes ? `${Math.round(c.duration_minutes)} د` : "—"}</td>
                    <td className="num">{c.rating ? "★".repeat(c.rating) : "—"}</td>
                    <td><Status value={c.status} /></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
