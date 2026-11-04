import { FormEvent, useState } from "react";
import { api, Resource } from "../api";
import { Modal, PageHead, useLoad } from "../components/ui";

const cats: Record<string, string> = {
  ingestion: "البلع والتسمم",
  prevention: "الوقاية",
  choking: "الاختناق",
  burns: "الحروق",
  bleeding: "النزيف",
  general: "عام",
};

const blank: Resource = {
  id: 0, slug: "", title_ar: "", title_en: "", category: "ingestion", summary_ar: "",
  content_ar: "", media_type: "text", media_path: null, available_offline: true, sort_order: 0,
};

export default function Library() {
  const { data, reload } = useLoad(() => api.get<Resource[]>("/education"));
  const [edit, setEdit] = useState<Resource | null>(null);

  const grouped = Object.keys(cats).map((k) => [k, (data ?? []).filter((r) => r.category === k)] as const);

  return (
    <>
      <PageHead title="المكتبة التوعوية" sub="محتوى الوقاية والإسعافات. المقالات المعلّمة 'بدون إنترنت' تُحفظ داخل التطبيق.">
        <button className="btn primary" onClick={() => setEdit({ ...blank })}>+ مقال جديد</button>
      </PageHead>

      <div className="grid g3">
        {grouped.map(([k, items]) => (
          <div className="card pad" key={k}>
            <h3>{cats[k]}</h3>
            <div className="sub">{items.length} مقال</div>
            {items.map((r) => (
              <button
                key={r.slug}
                onClick={() => setEdit(r)}
                style={{ display: "block", width: "100%", textAlign: "start", background: "none", border: 0, borderTop: "1px solid var(--line-2)", padding: "11px 0", cursor: "pointer" }}
              >
                <div style={{ fontWeight: 600, fontSize: 14.5 }}>{r.title_ar}</div>
                <div className="faint" style={{ fontSize: 12.5, marginTop: 2 }}>
                  {r.content_ar.split("\n").length} خطوات {r.available_offline && "· بدون إنترنت"}
                </div>
              </button>
            ))}
          </div>
        ))}
      </div>

      {edit && <ResourceForm value={edit} onClose={() => setEdit(null)} onSaved={() => { setEdit(null); reload(); }} />}
    </>
  );
}

function ResourceForm({ value, onClose, onSaved }: { value: Resource; onClose: () => void; onSaved: () => void }) {
  const [f, setF] = useState(value);
  const [err, setErr] = useState("");
  const isNew = !value.id;

  async function save(e: FormEvent) {
    e.preventDefault();
    const { id: _id, ...body } = f;
    try {
      if (isNew) await api.post("/education", body);
      else await api.put(`/education/${value.slug}`, body);
      onSaved();
    } catch (e) {
      setErr((e as Error).message);
    }
  }

  async function remove() {
    if (!confirm("حذف المقال؟")) return;
    await api.del(`/education/${value.slug}`);
    onSaved();
  }

  return (
    <Modal title={isNew ? "مقال جديد" : f.title_ar} onClose={onClose}>
      <form onSubmit={save}>
        <div className="row">
          <label className="field">العنوان<input className="input" required value={f.title_ar} onChange={(e) => setF({ ...f, title_ar: e.target.value })} /></label>
          <label className="field">المعرّف (slug)<input className="input ltr" required pattern="[a-z0-9-]{3,80}" disabled={!isNew} value={f.slug} onChange={(e) => setF({ ...f, slug: e.target.value })} /></label>
        </div>
        <div className="row">
          <label className="field">
            التصنيف
            <select className="input" value={f.category} onChange={(e) => setF({ ...f, category: e.target.value })}>
              {Object.entries(cats).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
            </select>
          </label>
          <label className="field">الترتيب<input className="input num" type="number" value={f.sort_order} onChange={(e) => setF({ ...f, sort_order: +e.target.value })} /></label>
        </div>
        <label className="field full">نبذة<input className="input" value={f.summary_ar ?? ""} onChange={(e) => setF({ ...f, summary_ar: e.target.value })} /></label>
        <label className="field full">الخطوات (سطر لكل خطوة)<textarea className="input" rows={7} required value={f.content_ar} onChange={(e) => setF({ ...f, content_ar: e.target.value })} /></label>
        <label style={{ display: "flex", gap: 8, alignItems: "center", fontSize: 14 }}>
          <input type="checkbox" checked={f.available_offline} onChange={(e) => setF({ ...f, available_offline: e.target.checked })} />
          متاح بدون إنترنت
        </label>
        {err && <p className="error">{err}</p>}
        <div className="foot">
          <button className="btn primary">حفظ</button>
          <button className="btn" type="button" onClick={onClose}>إلغاء</button>
          {!isNew && <button className="btn danger" type="button" onClick={remove} style={{ marginInlineStart: "auto" }}>حذف</button>}
        </div>
      </form>
    </Modal>
  );
}
