import { ReactNode, useEffect, useState } from "react";

export const severityLabel: Record<string, string> = {
  low: "بسيطة",
  moderate: "متوسطة",
  high: "خطيرة",
  critical: "خطيرة جداً",
  unknown: "غير محددة",
};

export const categoryLabel: Record<string, string> = {
  corrosive: "مواد كاوية",
  hydrocarbon: "مشتقات نفطية",
  detergent_pod: "كبسولات غسيل",
  detergent_mild: "منظفات خفيفة",
  button_battery: "بطاريات زر",
  magnet: "مغناطيس",
  medication: "أدوية",
  pesticide: "مبيدات",
  alcohol: "مواد كحولية",
  essential_oil: "زيوت عطرية",
  low_toxicity: "منخفضة السمية",
  unknown: "غير معروف",
};

export const statusLabel: Record<string, [string, string]> = {
  pending: ["بانتظار متطوع", "moderate"],
  active: ["جارية", "brand"],
  completed: ["مكتملة", "low"],
  cancelled: ["ملغاة", "neutral"],
};

export function Severity({ value }: { value: string }) {
  return <span className={`tag ${value}`}>{severityLabel[value] ?? value}</span>;
}

export function Status({ value }: { value: string }) {
  const [label, tone] = statusLabel[value] ?? [value, "neutral"];
  return <span className={`tag ${tone}`}>{label}</span>;
}

export function PageHead({ title, sub, children }: { title: string; sub?: string; children?: ReactNode }) {
  return (
    <div className="page-head">
      <div>
        <h1>{title}</h1>
        {sub && <p>{sub}</p>}
      </div>
      {children && <div style={{ display: "flex", gap: 10 }}>{children}</div>}
    </div>
  );
}

export function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  useEffect(() => {
    const esc = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", esc);
    return () => window.removeEventListener("keydown", esc);
  }, [onClose]);

  return (
    <div className="backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal" role="dialog" aria-label={title}>
        <h2>{title}</h2>
        {children}
      </div>
    </div>
  );
}

export function fmtDate(iso: string | null, withTime = true) {
  if (!iso) return "—";
  // api sends naive UTC timestamps
  const d = new Date(iso.endsWith("Z") ? iso : iso + "Z");
  return d.toLocaleString("ar-SA-u-nu-latn", {
    day: "numeric",
    month: "short",
    ...(withTime ? { hour: "2-digit", minute: "2-digit" } : { year: "numeric" }),
  });
}

/** Small hook for "load this on mount and let me reload it". */
export function useLoad<T>(fn: () => Promise<T>, deps: unknown[] = []) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [tick, setTick] = useState(0);

  useEffect(() => {
    let alive = true;
    fn()
      .then((d) => alive && (setData(d), setError(null)))
      .catch((e) => alive && setError(e.message));
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, tick]);

  return { data, error, reload: () => setTick((t) => t + 1) };
}
