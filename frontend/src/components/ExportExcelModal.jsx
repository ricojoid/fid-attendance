import React, { useState } from 'react';
import { X, FileSpreadsheet, Loader2, Download } from 'lucide-react';
import api from '../api/client';

const fmt = (d) => d.toLocaleDateString('en-CA');
const startOfWeek = (d) => {
  const x = new Date(d);
  const day = (x.getDay() + 6) % 7; // Monday = 0
  x.setDate(x.getDate() - day);
  return x;
};

const PRESETS = [
  ['This month', () => { const n = new Date(); return [new Date(n.getFullYear(), n.getMonth(), 1), n]; }],
  ['Last month', () => { const n = new Date(); return [new Date(n.getFullYear(), n.getMonth() - 1, 1), new Date(n.getFullYear(), n.getMonth(), 0)]; }],
  ['This week', () => [startOfWeek(new Date()), new Date()]],
  ['Last 7 days', () => { const n = new Date(); const s = new Date(n); s.setDate(n.getDate() - 6); return [s, n]; }],
  ['Last 30 days', () => { const n = new Date(); const s = new Date(n); s.setDate(n.getDate() - 29); return [s, n]; }],
];

/** Pick a date range and download a styled Excel workbook from the server. */
export default function ExportExcelModal({ onClose, userId, userName, defaultFrom, defaultTo }) {
  const now = new Date();
  const [from, setFrom] = useState(defaultFrom || fmt(new Date(now.getFullYear(), now.getMonth(), 1)));
  const [to, setTo] = useState(defaultTo || fmt(now));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const download = async () => {
    if (from > to) {
      setError('The start date must be before the end date.');
      return;
    }
    setBusy(true);
    setError('');
    try {
      const params = new URLSearchParams({ from, to });
      if (userId) params.set('user_id', userId);
      const res = await api.get(`/attendance/export?${params}`, { responseType: 'blob', timeout: 120000 });
      const cd = res.headers['content-disposition'] || '';
      const name = /filename="([^"]+)"/.exec(cd)?.[1] || `attendance_${from}_to_${to}.xlsx`;
      const url = URL.createObjectURL(res.data);
      const a = document.createElement('a');
      a.href = url;
      a.download = name;
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 2000);
      onClose();
    } catch (e) {
      let msg = 'Export failed';
      try {
        msg = JSON.parse(await e.response.data.text()).error || msg;
      } catch (_) {
        /* not JSON */
      }
      setError(msg);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-sm animate-fade-in" onClick={onClose}>
      <div className="w-full max-w-md bg-white rounded-[28px] shadow-2xl animate-scale-in overflow-hidden" onClick={(e) => e.stopPropagation()}>
        <div className="p-6 pb-4 flex items-start gap-3">
          <div className="p-3 rounded-2xl bg-emerald-50 text-emerald-600">
            <FileSpreadsheet className="w-6 h-6" />
          </div>
          <div className="flex-1">
            <h3 className="text-xl font-extrabold tracking-tight text-slate-900">Export to Excel</h3>
            <p className="text-sm text-slate-500">{userName ? `${userName} · ` : ''}Summary, daily detail & daily recap sheets.</p>
          </div>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-slate-100 text-slate-500">
            <X className="w-4 h-4" />
          </button>
        </div>
        <div className="px-6 space-y-4">
          <div className="flex flex-wrap gap-2">
            {PRESETS.map(([label, fn]) => (
              <button
                key={label}
                onClick={() => {
                  const [a, b] = fn();
                  setFrom(fmt(a));
                  setTo(fmt(b));
                }}
                className="px-3 py-1.5 rounded-xl text-xs font-bold bg-slate-100 text-slate-700 hover:bg-brand-50 hover:text-brand-700 transition-colors"
              >
                {label}
              </button>
            ))}
          </div>
          <div className="grid grid-cols-2 gap-3">
            {[
              ['From', from, setFrom],
              ['To', to, setTo],
            ].map(([label, v, set]) => (
              <label key={label} className="block">
                <span className="block text-xs font-bold text-slate-600 mb-1.5">{label}</span>
                <input
                  type="date"
                  value={v}
                  onChange={(e) => e.target.value && set(e.target.value)}
                  className="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-2xl text-sm font-semibold text-slate-900 focus:outline-none focus:ring-4 focus:ring-brand-500/15 focus:border-brand-500"
                />
              </label>
            ))}
          </div>
          {error && <div className="p-3 rounded-2xl bg-rose-50 text-rose-700 text-sm font-semibold">{error}</div>}
        </div>
        <div className="p-6 pt-5">
          <button
            onClick={download}
            disabled={busy}
            className="w-full py-3.5 rounded-2xl bg-gradient-to-br from-emerald-400 to-emerald-600 text-white font-extrabold text-sm shadow-lg shadow-emerald-500/25 hover:brightness-105 active:scale-[0.98] transition-all disabled:opacity-60 inline-flex items-center justify-center gap-2"
          >
            {busy ? <Loader2 className="w-4 h-4 animate-spin" /> : <Download className="w-4 h-4" />}
            {busy ? 'Building workbook…' : 'Download .xlsx'}
          </button>
        </div>
      </div>
    </div>
  );
}
