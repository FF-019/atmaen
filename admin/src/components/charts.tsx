import { useMemo, useState } from "react";

/**
 * Daily cases, one series. Bars instead of a line because most days have
 * 0-3 cases and a line would look like a heartbeat monitor.
 */
export function DailyBars({ data, height = 200 }: { data: { date: string; count: number }[]; height?: number }) {
  const [hover, setHover] = useState<number | null>(null);

  // fill missing days so gaps show as gaps
  const days = useMemo(() => {
    if (!data.length) return [];
    const map = new Map(data.map((d) => [d.date, d.count]));
    const start = new Date(data[0].date);
    const end = new Date();
    const out: { date: string; count: number }[] = [];
    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      const key = d.toISOString().slice(0, 10);
      out.push({ date: key, count: map.get(key) ?? 0 });
    }
    return out;
  }, [data]);

  if (!days.length) return <div className="empty">لا توجد حالات في هذه الفترة</div>;

  const W = 720;
  const pad = { top: 10, bottom: 24, left: 4, right: 28 };
  const max = Math.max(4, ...days.map((d) => d.count));
  const ticks = [0, Math.ceil(max / 2), max];
  const step = (W - pad.left - pad.right) / days.length;
  const bw = Math.max(3, step - 3);
  const y = (v: number) => pad.top + (height - pad.top - pad.bottom) * (1 - v / max);
  // RTL page but time still runs left to right, like every chart people know
  const x = (i: number) => pad.left + i * step;

  const h = hover !== null ? days[hover] : null;

  return (
    <div className="chart ltr">
      <svg viewBox={`0 0 ${W} ${height}`} onMouseLeave={() => setHover(null)}>
        {ticks.map((t) => (
          <g key={t}>
            <line className="grid-line" x1={pad.left} x2={W - pad.right} y1={y(t)} y2={y(t)} />
            <text className="axis-text" x={W - pad.right + 6} y={y(t) + 4}>
              {t}
            </text>
          </g>
        ))}
        {days.map((d, i) => {
          const top = y(d.count);
          const bottom = y(0);
          const hgt = Math.max(0, bottom - top);
          const r = Math.min(4, bw / 2, hgt);
          return (
            <g key={d.date}>
              {d.count > 0 && (
                <path
                  className={`bar ${hover !== null && hover !== i ? "dim" : ""}`}
                  d={`M${x(i)},${bottom} v${-(hgt - r)} q0,${-r} ${r},${-r} h${bw - 2 * r} q${r},0 ${r},${r} v${hgt - r} z`}
                />
              )}
              <rect className="hit" x={x(i) - 1} y={pad.top} width={step} height={height - pad.top - pad.bottom} onMouseEnter={() => setHover(i)} />
              {i % 7 === 0 && (
                <text className="axis-text" x={x(i)} y={height - 6}>
                  {d.date.slice(5).replace("-", "/")}
                </text>
              )}
            </g>
          );
        })}
      </svg>
      {h && hover !== null && (
        <div className="tooltip" style={{ left: `${((x(hover) + bw / 2) / W) * 100}%`, top: `${(y(h.count) / height) * 100}%`, transform: "translate(-50%, -115%)" }}>
          <b>{h.count}</b> حالة · {h.date}
        </div>
      )}
    </div>
  );
}

export function HBars({ rows, labelFor }: { rows: { key: string; value: number }[]; labelFor?: (k: string) => React.ReactNode }) {
  const max = Math.max(1, ...rows.map((r) => r.value));
  if (!rows.length) return <div className="empty">لا توجد بيانات</div>;
  return (
    <div>
      {rows.map((r) => (
        <div className="hbar" key={r.key} title={`${r.value}`}>
          <div>{labelFor ? labelFor(r.key) : r.key}</div>
          <div className="track">
            <div className="fill" style={{ width: `${(r.value / max) * 100}%` }} />
          </div>
          <div className="v num">{r.value}</div>
        </div>
      ))}
    </div>
  );
}
