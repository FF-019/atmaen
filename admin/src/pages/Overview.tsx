import { useState } from "react";
import { api, Stats } from "../api";
import { DailyBars, HBars } from "../components/charts";
import { PageHead, Severity, useLoad } from "../components/ui";

const methodLabel: Record<string, string> = { text: "كتابة الاسم", barcode: "مسح الباركود", image: "تصوير العبوة" };

export default function Overview() {
  const [days, setDays] = useState(30);
  const { data: s, error } = useLoad(() => api.get<Stats>(`/admin/stats?days=${days}`), [days]);

  return (
    <>
      <PageHead title="نظرة عامة" sub="كيف يستخدم الناس اطمئن، وأين يحتاجون المساعدة">
        <div className="seg">
          {[7, 30, 90].map((d) => (
            <button key={d} className={d === days ? "on" : ""} onClick={() => setDays(d)}>
              {d} يوم
            </button>
          ))}
        </div>
        <button className="btn" onClick={() => api.download(`/admin/reports/cases.csv?days=${days}`, `atmaen-cases-${days}d.csv`)}>
          تصدير CSV
        </button>
      </PageHead>

      {error && <p className="error">{error}</p>}
      {!s ? (
        <div className="empty">جاري التحميل...</div>
      ) : (
        <>
          <div className="grid g4" style={{ marginBottom: 16 }}>
            <div className="card kpi dark">
              <div className="label">حالات طوارئ</div>
              <div className="value num">{s.cases}</div>
              <div className="hint">
                منها <b style={{ color: "#fff" }}>{s.critical_cases}</b> خطيرة جداً · آخر {s.period_days} يوم
              </div>
            </div>
            <div className="card kpi">
              <div className="label">متوسط انتظار المتطوع</div>
              <div className="value num">
                {s.avg_wait_minutes ?? "—"}
                <small>دقيقة</small>
              </div>
              <div className="hint">من الطلب حتى القبول</div>
            </div>
            <div className="card kpi">
              <div className="label">دقة التعرف على المادة</div>
              <div className="value num">
                {s.ai_match_rate === null ? "—" : Math.round(s.ai_match_rate * 100)}
                <small>٪</small>
              </div>
              <div className="hint">{s.ai_requests} طلب تحليل</div>
            </div>
            <div className="card kpi">
              <div className="label">تقييم الاستشارات</div>
              <div className="value num">
                {s.avg_rating ?? "—"}
                <small>/ 5</small>
              </div>
              <div className="hint">{s.completed_consultations} استشارة مكتملة</div>
            </div>
          </div>

          <div className="grid g2" style={{ marginBottom: 16 }}>
            <div className="card pad">
              <h3>الحالات يومياً</h3>
              <div className="sub">مرّر على الأعمدة لرؤية العدد</div>
              <DailyBars data={s.cases_by_day} />
            </div>
            <div className="card pad">
              <h3>حسب الخطورة</h3>
              <div className="sub">بعد احتساب الأعراض</div>
              <HBars
                rows={["critical", "high", "moderate", "low"].map((k) => ({ key: k, value: s.by_severity[k] ?? 0 }))}
                labelFor={(k) => <Severity value={k} />}
              />
            </div>
          </div>

          <div className="grid g3">
            <div className="card pad">
              <h3>أكثر المواد</h3>
              <div className="sub">ما يجب التركيز عليه في التوعية</div>
              <HBars rows={s.top_substances.map((t) => ({ key: t.name, value: t.count }))} />
            </div>
            <div className="card pad">
              <h3>طريقة الإدخال</h3>
              <div className="sub">كيف يتعرف الأهل على المادة</div>
              <HBars
                rows={Object.entries(s.by_method).map(([k, v]) => ({ key: k, value: v })).sort((a, b) => b.value - a.value)}
                labelFor={(k) => methodLabel[k] ?? k}
              />
            </div>
            <div className="card pad">
              <h3>المجتمع</h3>
              <div className="sub">
                <span className="live-dot" /> &nbsp;{s.volunteers_online} متطوع متاح الآن
              </div>
              <table className="table">
                <tbody>
                  <tr><td>أولياء أمور</td><td className="num actions">{s.totals.parents}</td></tr>
                  <tr><td>أطفال مسجلون</td><td className="num actions">{s.totals.children}</td></tr>
                  <tr><td>متطوعون موثقون</td><td className="num actions">{s.totals.volunteers}</td></tr>
                  <tr><td>بانتظار التحقق</td><td className="num actions">{s.totals.pending_volunteers}</td></tr>
                  <tr><td>مواد في القاعدة</td><td className="num actions">{s.totals.chemicals}</td></tr>
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}
    </>
  );
}
