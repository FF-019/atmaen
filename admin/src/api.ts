const BASE = import.meta.env.VITE_API_URL ?? "";

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

let token: string | null = localStorage.getItem("atmaen_admin_token");

export function setToken(t: string | null) {
  token = t;
  if (t) localStorage.setItem("atmaen_admin_token", t);
  else localStorage.removeItem("atmaen_admin_token");
}

export const hasToken = () => !!token;

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const res = await fetch(`${BASE}/api${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  if (res.status === 401) {
    setToken(null);
    window.location.hash = "#/login";
  }
  if (res.status === 204) return undefined as T;

  const data = await res.json().catch(() => null);
  if (!res.ok) {
    const detail = data?.detail;
    throw new ApiError(res.status, typeof detail === "string" ? detail : "request failed");
  }
  return data as T;
}

export const api = {
  get: <T,>(p: string) => request<T>("GET", p),
  post: <T,>(p: string, b?: unknown) => request<T>("POST", p, b ?? {}),
  patch: <T,>(p: string, b: unknown) => request<T>("PATCH", p, b),
  put: <T,>(p: string, b: unknown) => request<T>("PUT", p, b),
  del: (p: string) => request<void>("DELETE", p),
  csvUrl: (days: number) => `${BASE}/api/admin/reports/cases.csv?days=${days}`,
  async download(path: string, filename: string) {
    const res = await fetch(`${BASE}/api${path}`, { headers: { Authorization: `Bearer ${token}` } });
    const blob = await res.blob();
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    a.click();
    URL.revokeObjectURL(a.href);
  },
};

// shapes we use from the API --------------------------------------------

export type User = {
  id: number;
  name: string;
  email: string;
  phone: string | null;
  role: "parent" | "volunteer" | "admin";
  is_active: boolean;
  created_at: string;
  specialty: string | null;
  institution: string | null;
  is_verified: boolean;
  is_available: boolean;
};

export type Chemical = {
  id: number;
  name_en: string;
  name_ar: string;
  aliases: string | null;
  category: string;
  hazard_level: "low" | "moderate" | "high" | "critical";
  description_ar: string | null;
  extra_steps_ar: string | null;
  products?: { id: number; barcode: string; brand: string }[];
};

export type Consultation = {
  id: number;
  case_id: number;
  status: string;
  created_at: string;
  start_time: string | null;
  end_time: string | null;
  duration_minutes: number;
  rating: number | null;
  volunteer: { id: number; name: string; specialty: string | null } | null;
  parent: { id: number; name: string } | null;
};

export type Stats = {
  period_days: number;
  totals: { parents: number; volunteers: number; pending_volunteers: number; children: number; chemicals: number };
  cases: number;
  critical_cases: number;
  consultations: number;
  completed_consultations: number;
  avg_wait_minutes: number | null;
  avg_rating: number | null;
  ai_requests: number;
  ai_match_rate: number | null;
  cases_by_day: { date: string; count: number }[];
  by_severity: Record<string, number>;
  by_method: Record<string, number>;
  top_substances: { name: string; count: number }[];
  volunteers_online: number;
};

export type Resource = {
  id: number;
  slug: string;
  title_ar: string;
  title_en: string | null;
  category: string;
  summary_ar: string | null;
  content_ar: string;
  media_type: string;
  media_path: string | null;
  available_offline: boolean;
  sort_order: number;
};

export type Audit = { id: number; user_id: number | null; action: string; detail: string | null; ip: string | null; created_at: string };
