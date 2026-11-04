import { FormEvent, useState } from "react";
import { api, Chemical } from "../api";
import { categoryLabel, Modal, PageHead, Severity, useLoad } from "../components/ui";

const empty: Partial<Chemical> = { name_ar: "", name_en: "", aliases: "", category: "corrosive", hazard_level: "moderate" };

export default function Chemicals() {
  const [q, setQ] = useState("");
  const [cat, setCat] = useState("");
  const [editing, setEditing] = useState<Partial<Chemical> | null>(null);

  const params = new URLSearchParams({ limit: "500" });
  if (q.trim()) params.set("q", q.trim());
  if (cat) params.set("category", cat);
  const { data, reload } = useLoad(() => api.get<Chemical[]>(`/chemicals?${params}`), [q, cat]);

  async function open(c: Chemical) {
    // fetch products too
    setEditing(await api.get<Chemical>(`/chemicals/${c.id}`));
  }

  async function remove(c: Chemical) {
    if (!confirm(`حذف "${c.name_ar}"؟ ستتوقف التطبيقات عن التعرف عليها.`)) return;
    await api.del(`/chemicals/${c.id}`);
    reload();
  }

  return (
    <>
      <PageHead title="قاعدة المواد" sub="ما يتعرف عليه الذكاء الاصطناعي. أي تعديل يصل للتطبيقات مع التحديث القادم.">
        <button className="btn primary" onClick={() => setEditing({ ...empty })}>
          + مادة جديدة
        </button>
      </PageHead>

      <div className="toolbar">
        <input className="input" placeholder="بحث بالاسم أو الاسم البديل" value={q} onChange={(e) => setQ(e.target.value)} />
        <select className="input" style={{ maxWidth: 200 }} value={cat} onChange={(e) => setCat(e.target.value)}>
          <option value="">كل الفئات</option>
          {Object.entries(categoryLabel)
            .filter(([k]) => k !== "unknown")
            .map(([k, l]) => (
              <option key={k} value={k}>{l}</option>
            ))}
        </select>
        <span className="faint" style={{ fontSize: 13 }}>{data?.length ?? 0} مادة</span>
      </div>

      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>المادة</th>
              <th>الفئة</th>
              <th>الخطورة</th>
              <th>أسماء بديلة</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {data?.map((c) => (
              <tr key={c.id}>
                <td>
                  <div style={{ fontWeight: 600 }}>{c.name_ar}</div>
                  <div className="faint ltr" style={{ fontSize: 12.5, textAlign: "right" }}>{c.name_en}</div>
                </td>
                <td>{categoryLabel[c.category] ?? c.category}</td>
                <td><Severity value={c.hazard_level} /></td>
                <td className="muted" style={{ maxWidth: 320, fontSize: 13 }}>
                  {(c.aliases ?? "").split(",").slice(0, 4).join("، ")}
                  {(c.aliases ?? "").split(",").length > 4 && " …"}
                </td>
                <td className="actions">
                  <button className="btn small" onClick={() => open(c)}>تعديل</button>{" "}
                  <button className="btn small danger" onClick={() => remove(c)}>حذف</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {editing && (
        <ChemicalForm
          value={editing}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null);
            reload();
          }}
        />
      )}
    </>
  );
}

function ChemicalForm({ value, onClose, onSaved }: { value: Partial<Chemical>; onClose: () => void; onSaved: () => void }) {
  const [form, setForm] = useState(value);
  const [err, setErr] = useState("");
  const [barcode, setBarcode] = useState("");
  const [brand, setBrand] = useState("");
  const set = (k: keyof Chemical) => (e: { target: { value: string } }) => setForm({ ...form, [k]: e.target.value });

  async function save(e: FormEvent) {
    e.preventDefault();
    setErr("");
    const body = {
      name_ar: form.name_ar,
      name_en: form.name_en,
      aliases: form.aliases || null,
      category: form.category,
      hazard_level: form.hazard_level,
      description_ar: form.description_ar || null,
      extra_steps_ar: form.extra_steps_ar || null,
    };
    try {
      if (form.id) await api.patch(`/chemicals/${form.id}`, body);
      else await api.post(`/chemicals`, body);
      onSaved();
    } catch (e) {
      setErr((e as Error).message);
    }
  }

  async function addProduct() {
    if (!form.id || !barcode.trim()) return;
    try {
      await api.post(`/chemicals/${form.id}/products`, { barcode, brand: brand || "—" });
      setForm(await api.get<Chemical>(`/chemicals/${form.id}`));
      setBarcode("");
      setBrand("");
    } catch (e) {
      setErr((e as Error).message);
    }
  }

  async function removeProduct(id: number) {
    await api.del(`/chemicals/products/${id}`);
    setForm(await api.get<Chemical>(`/chemicals/${form.id}`));
  }

  return (
    <Modal title={form.id ? `تعديل: ${value.name_ar}` : "مادة جديدة"} onClose={onClose}>
      <form onSubmit={save}>
        <div className="row">
          <label className="field">الاسم بالعربي<input className="input" required value={form.name_ar ?? ""} onChange={set("name_ar")} /></label>
          <label className="field">الاسم بالإنجليزي<input className="input ltr" required value={form.name_en ?? ""} onChange={set("name_en")} /></label>
        </div>
        <div className="row">
          <label className="field">
            الفئة (تحدد خطوات الإسعاف)
            <select className="input" value={form.category} onChange={set("category")}>
              {Object.entries(categoryLabel).filter(([k]) => k !== "unknown").map(([k, l]) => <option key={k} value={k}>{l}</option>)}
            </select>
          </label>
          <label className="field">
            درجة الخطورة
            <select className="input" value={form.hazard_level} onChange={set("hazard_level")}>
              <option value="low">بسيطة</option>
              <option value="moderate">متوسطة</option>
              <option value="high">خطيرة</option>
              <option value="critical">خطيرة جداً</option>
            </select>
          </label>
        </div>
        <label className="field full">
          أسماء بديلة وأخطاء إملائية شائعة (مفصولة بفاصلة)
          <textarea className="input" rows={2} value={form.aliases ?? ""} onChange={set("aliases")} />
        </label>
        <label className="field full">
          خطوات إضافية خاصة بهذه المادة (سطر لكل خطوة)
          <textarea className="input" rows={2} value={form.extra_steps_ar ?? ""} onChange={set("extra_steps_ar")} />
        </label>

        {form.id && (
          <div className="full">
            <div className="field" style={{ marginBottom: 8 }}>المنتجات المرتبطة (الباركود)</div>
            {form.products?.map((p) => (
              <div key={p.id} style={{ display: "flex", justifyContent: "space-between", padding: "6px 0", borderBottom: "1px solid var(--line-2)", fontSize: 14 }}>
                <span>{p.brand}</span>
                <span>
                  <span className="ltr num muted">{p.barcode}</span>{" "}
                  <button type="button" className="btn small danger" onClick={() => removeProduct(p.id)}>×</button>
                </span>
              </div>
            ))}
            <div style={{ display: "flex", gap: 8, marginTop: 10 }}>
              <input className="input ltr" placeholder="barcode" value={barcode} onChange={(e) => setBarcode(e.target.value)} />
              <input className="input" placeholder="اسم المنتج" value={brand} onChange={(e) => setBrand(e.target.value)} />
              <button type="button" className="btn" onClick={addProduct}>إضافة</button>
            </div>
          </div>
        )}

        {err && <p className="error">{err}</p>}
        <div className="foot">
          <button className="btn primary" type="submit">حفظ</button>
          <button className="btn" type="button" onClick={onClose}>إلغاء</button>
        </div>
      </form>
    </Modal>
  );
}
