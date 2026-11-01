import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Check, X, Inbox, CalendarRange, AlarmClock, RefreshCw, UserRound, ArrowRight, Loader2 } from 'lucide-react';
import { getPendingApprovals, processApproval } from '../api/client';
import { useAuth } from '../context/AuthContext';

const TABS = [
  { key: 'ALL', label: 'All' },
  { key: 'LEAVE', label: 'Leave' },
  { key: 'ATTENDANCE', label: 'Corrections' },
];

function Avatar({ name, src }) {
  if (src && (src.startsWith('http') || src.startsWith('data:image'))) {
    return <img src={src} alt="" loading="lazy" decoding="async" className="w-11 h-11 rounded-2xl object-cover" />;
  }
  return (
    <div className="w-11 h-11 rounded-2xl bg-gradient-to-br from-brand-400 to-brand-700 text-white font-extrabold flex items-center justify-center">
      {(name || '?').charAt(0).toUpperCase()}
    </div>
  );
}

function RequestCard({ item, busy, onDecide }) {
  const leave = item.category === 'LEAVE';
  const Icon = leave ? CalendarRange : AlarmClock;
  return (
    <div className="bg-white rounded-3xl border border-slate-200/80 p-5 shadow-soft transition-all duration-300 hover:shadow-xl hover:-translate-y-0.5">
      <div className="flex items-start gap-4">
        <Avatar name={item.applicant_name} src={item.applicant_avatar} />
        <div className="flex-1 min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <p className="font-extrabold text-slate-900">{item.applicant_name}</p>
            <span className="text-[11px] text-slate-400 font-semibold">{item.department}</span>
            <span
              className={`ml-auto inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10.5px] font-extrabold tracking-wide ${
                leave ? 'bg-sky-50 text-sky-700' : 'bg-amber-50 text-amber-700'
              }`}
            >
              <Icon className="w-3.5 h-3.5" /> {item.request_type}
            </span>
          </div>
          <p className="text-sm font-bold text-slate-800 mt-2">{item.period}</p>
          <p className="text-sm text-slate-500 mt-1 leading-relaxed">“{item.reason}”</p>
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1 mt-3 text-[11px] text-slate-400 font-semibold">
            <span>Submitted {item.created_at}</span>
            {item.approver && (
              <span className="inline-flex items-center gap-1">
                <ArrowRight className="w-3 h-3" /> Routed to <b className="text-slate-600">{item.approver.name}</b>
              </span>
            )}
          </div>
        </div>
      </div>
      <div className="flex gap-2.5 mt-4">
        <button
          disabled={busy}
          onClick={() => onDecide(item, 'REJECTED')}
          className="flex-1 inline-flex items-center justify-center gap-1.5 py-2.5 rounded-2xl border border-slate-200 text-slate-700 font-bold text-sm hover:bg-rose-50 hover:border-rose-200 hover:text-rose-700 active:scale-[0.98] transition-all disabled:opacity-50"
        >
          <X className="w-4 h-4" /> Reject
        </button>
        <button
          disabled={busy}
          onClick={() => onDecide(item, 'APPROVED')}
          className="flex-1 inline-flex items-center justify-center gap-1.5 py-2.5 rounded-2xl bg-gradient-to-br from-emerald-400 to-emerald-600 text-white font-bold text-sm shadow-lg shadow-emerald-500/25 hover:brightness-105 active:scale-[0.98] transition-all disabled:opacity-50"
        >
          {busy ? <Loader2 className="w-4 h-4 animate-spin" /> : <Check className="w-4 h-4" />} Approve
        </button>
      </div>
    </div>
  );
}

export default function Approvals() {
  const { user } = useAuth();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState('ALL');
  const [busyKey, setBusyKey] = useState(null);
  const [toast, setToast] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setItems(await getPendingApprovals());
    } catch (e) {
      setToast({ type: 'error', text: e.response?.data?.error || 'Failed to load approvals' });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (!toast) return undefined;
    const t = setTimeout(() => setToast(null), 3200);
    return () => clearTimeout(t);
  }, [toast]);

  const decide = async (item, status) => {
    const key = `${item.category}-${item.id}`;
    setBusyKey(key);
    try {
      await processApproval(item.category, item.id, status);
      setItems((list) => list.filter((x) => `${x.category}-${x.id}` !== key));
      setToast({ type: 'ok', text: `${item.applicant_name}'s request ${status.toLowerCase()}` });
    } catch (e) {
      setToast({ type: 'error', text: e.response?.data?.error || 'Failed to process request' });
      if (e.response?.status === 409) load(); // already processed elsewhere
    } finally {
      setBusyKey(null);
    }
  };

  const filtered = useMemo(() => (tab === 'ALL' ? items : items.filter((i) => i.category === tab)), [items, tab]);
  const count = (k) => (k === 'ALL' ? items.length : items.filter((i) => i.category === k).length);
  const approverName = user?.approver?.name;

  return (
    <div className="max-w-5xl mx-auto space-y-6">
      <section className="aurora rounded-[32px] p-7 text-white shadow-2xl">
        <span className="aurora-blob" />
        <div className="relative flex flex-col md:flex-row md:items-end justify-between gap-5">
          <div>
            <p className="text-white/70 text-xs font-extrabold tracking-[0.25em]">APPROVAL CENTER</p>
            <h1 className="text-3xl font-extrabold tracking-tight mt-2">Requests waiting for you</h1>
            <p className="text-white/60 text-sm mt-1">Leave and attendance-correction requests routed to you.</p>
          </div>
          <div className="flex items-end gap-6">
            <div>
              <p className="text-6xl font-extrabold leading-none tabular-nums">{loading ? '–' : items.length}</p>
              <p className="text-xs text-white/60 font-semibold mt-1">pending</p>
            </div>
            <button
              onClick={load}
              className="p-3 rounded-2xl bg-white/10 border border-white/15 hover:bg-white/20 transition-colors"
              title="Refresh"
            >
              <RefreshCw className={`w-5 h-5 ${loading ? 'animate-spin' : ''}`} />
            </button>
          </div>
        </div>
      </section>

      {approverName && (
        <div className="flex items-center gap-3 p-4 rounded-2xl bg-indigo-50 border border-indigo-100 text-sm">
          <UserRound className="w-5 h-5 text-indigo-500" />
          <span className="text-indigo-900">
            Your own requests are sent to <b>{approverName}</b>
            {user?.approver?.role ? ` (${user.approver.role.replace(/_/g, ' ').toLowerCase()})` : ''}.
          </span>
        </div>
      )}

      <div className="inline-flex p-1 rounded-2xl bg-white border border-slate-200">
        {TABS.map((t) => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={`px-4 py-2 rounded-xl text-sm font-bold transition-all ${
              tab === t.key ? 'bg-slate-900 text-white shadow' : 'text-slate-500 hover:text-slate-900'
            }`}
          >
            {t.label} <span className="opacity-60">{count(t.key)}</span>
          </button>
        ))}
      </div>

      {loading ? (
        <div className="grid gap-4">
          {[0, 1, 2].map((i) => (
            <div key={i} className="h-44 rounded-3xl bg-slate-200/60 animate-pulse" />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <div className="bg-white rounded-3xl border border-slate-200/80 p-12 text-center animate-fade-in">
          <div className="mx-auto w-16 h-16 rounded-3xl bg-emerald-50 text-emerald-500 flex items-center justify-center">
            <Inbox className="w-8 h-8" />
          </div>
          <p className="font-extrabold text-slate-900 mt-4">All caught up</p>
          <p className="text-sm text-slate-500 mt-1">No pending requests need your decision.</p>
        </div>
      ) : (
        <div className="grid gap-4 stagger">
          {filtered.map((item) => (
            <RequestCard
              key={`${item.category}-${item.id}`}
              item={item}
              busy={busyKey === `${item.category}-${item.id}`}
              onDecide={decide}
            />
          ))}
        </div>
      )}

      {toast && (
        <div
          className={`fixed bottom-6 right-6 z-50 px-5 py-3 rounded-2xl text-sm font-bold shadow-2xl animate-slide-up ${
            toast.type === 'ok' ? 'bg-slate-900 text-white' : 'bg-rose-600 text-white'
          }`}
        >
          {toast.text}
        </div>
      )}
    </div>
  );
}
