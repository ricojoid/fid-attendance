import React, { useState } from 'react';
import { CalendarDays, Clock3, Moon, Trophy, Info, X, CheckCircle2, Flame, RefreshCw } from 'lucide-react';
import BadgeMedal, { StreakFlame, TIER_NAMES, accentFor } from '../components/BadgeMedal';
import { loadBadges, useBadges } from '../hooks/useBadges';
import api from '../api/client';

const fmtDate = (s) =>
  s ? new Date(s).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }) : '';

function ProgressBar({ value, color }) {
  return (
    <div className="h-2 rounded-full bg-slate-100 overflow-hidden">
      <div
        className="h-full rounded-full progress-grow"
        style={{ width: `${Math.round(Math.min(1, Math.max(0, value)) * 100)}%`, background: `linear-gradient(90deg, ${color}aa, ${color})` }}
      />
    </div>
  );
}

function NextGoal({ badge, streak }) {
  const color = streak ? '#FF7A1A' : '#8B5CF6';
  const Icon = streak ? Flame : Moon;
  return (
    <div className="bg-white rounded-3xl border border-slate-200/80 p-5 shadow-soft">
      <div className="flex items-center gap-2 text-[11px] font-extrabold tracking-wider" style={{ color }}>
        <Icon className="w-4 h-4" /> {streak ? 'NEXT STREAK BADGE' : 'NEXT OVERTIME BADGE'}
      </div>
      <div className="flex items-center gap-4 mt-3">
        {badge && <BadgeMedal badge={badge} size={64} showProgress={false} />}
        <div className="min-w-0 flex-1">
          <p className="font-extrabold text-slate-900 truncate">{badge ? badge.name : 'All unlocked! 🏆'}</p>
          <p className="text-xs text-slate-500 mt-0.5">
            {badge
              ? `${badge.target - badge.progress} more ${streak ? 'weekdays' : 'overtime days'} to go`
              : 'You have every badge in this category.'}
          </p>
          <div className="mt-3">
            <ProgressBar value={badge ? badge.percent : 1} color={color} />
          </div>
          <p className="text-[11px] font-bold text-slate-400 mt-1.5">
            {badge ? `${badge.progress}/${badge.target}` : '100%'}
          </p>
        </div>
      </div>
    </div>
  );
}

function BadgeCard({ badge, onOpen }) {
  const accent = accentFor(badge);
  return (
    <button
      onClick={() => onOpen(badge)}
      className="group text-left bg-white rounded-3xl border p-4 flex flex-col items-center transition-all duration-300 ease-emphasized hover:-translate-y-1.5 hover:shadow-xl active:scale-[0.98]"
      style={{
        borderColor: badge.earned ? `${accent}55` : '#e2e8f0',
        background: badge.earned ? `linear-gradient(180deg, ${accent}1f, rgb(var(--surface)) 55%)` : 'rgb(var(--surface))',
        boxShadow: badge.earned ? `0 14px 30px -18px ${accent}` : undefined,
      }}
    >
      <div className="transition-transform duration-300 group-hover:scale-105">
        <BadgeMedal badge={badge} size={112} />
      </div>
      <p className="mt-2 font-extrabold text-sm text-slate-900 text-center">{badge.name}</p>
      <p className="text-[11px] font-bold mt-0.5" style={{ color: badge.earned ? accent : '#94a3b8' }}>
        {badge.earned
          ? `Earned ${fmtDate(badge.earned_at)}`
          : `${badge.progress}/${badge.target} ${badge.category === 'STREAK' ? 'days' : 'OT days'}`}
      </p>
    </button>
  );
}

function BadgeDetail({ badge, onClose, featuredCode }) {
  const [busy, setBusy] = useState(false);
  if (!badge) return null;
  const featured = featuredCode === badge.code;
  const accent = accentFor(badge);
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-sm animate-fade-in" onClick={onClose}>
      <div
        className="relative w-full max-w-md bg-white rounded-[28px] p-7 text-center shadow-2xl animate-scale-in"
        onClick={(e) => e.stopPropagation()}
      >
        <button onClick={onClose} className="absolute top-4 right-4 p-2 rounded-xl hover:bg-slate-100 text-slate-500">
          <X className="w-4 h-4" />
        </button>
        <div className="flex justify-center">
          <BadgeMedal badge={badge} size={170} animate />
        </div>
        <span
          className="inline-block mt-2 px-3 py-1 rounded-full text-[11px] font-extrabold tracking-wider"
          style={{ color: accent, background: `${accent}18` }}
        >
          {TIER_NAMES[badge.tier]?.toUpperCase()} · {badge.category}
        </span>
        <h3 className="text-2xl font-extrabold tracking-tight text-slate-900 mt-2">{badge.name}</h3>
        <p className="text-sm text-slate-500 mt-1.5">{badge.description}</p>
        <div className="mt-6 text-left">
          {badge.earned ? (
            <>
              <div className="flex items-center gap-2.5 p-3.5 rounded-2xl bg-emerald-50 text-emerald-700 text-sm font-bold">
                <CheckCircle2 className="w-5 h-5" /> Unlocked on {fmtDate(badge.earned_at)}
              </div>
              <button
                disabled={busy}
                onClick={async () => {
                  setBusy(true);
                  try {
                    await api.put('/badges/feature', { code: featured ? '' : badge.code });
                    await loadBadges(true);
                  } finally {
                    setBusy(false);
                  }
                }}
                className={`mt-3 w-full py-3 rounded-2xl text-sm font-extrabold transition-all active:scale-[0.98] ${
                  featured ? 'border-2 border-brand-500 text-brand-600' : 'bg-gradient-to-br from-brand-400 to-brand-700 text-white shadow-glow'
                }`}
              >
                {busy ? '…' : featured ? '✓ Shown next to your name · click to unpin' : '📌 Show next to my name'}
              </button>
            </>
          ) : (
            <>
              <ProgressBar value={badge.percent} color={accent} />
              <p className="text-xs font-bold text-slate-500 mt-2">
                {badge.progress} of {badge.target} {badge.unit} · {badge.target - badge.progress} to go
              </p>
              {badge.category === 'STREAK' && (
                <div className="flex items-start gap-2 p-3 mt-4 rounded-2xl bg-indigo-50 text-indigo-700 text-xs font-semibold">
                  <Info className="w-4 h-4 shrink-0 mt-0.5" />
                  Missing a weekday — or covering it only with a correction request — resets the streak.
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function Rules() {
  const rows = [
    {
      icon: CalendarDays,
      color: '#FF7A1A',
      title: 'Daily streaks, live check-ins only',
      body: 'Every live check-in from the app adds 1 — even your very first day. Missing a weekday breaks the streak; weekends are optional (checking in adds, skipping never breaks). Days filled by an approved correction request do not count. 1 month = 22 days, 6 months = 130, 1 year = 260.',
    },
    {
      icon: Clock3,
      color: '#6366F1',
      title: '9-hour working day',
      body: '8 hours of work + 1 hour break. Being on site for 8 hours means 7 hours of actual work.',
    },
    {
      icon: Moon,
      color: '#8B5CF6',
      title: 'Overtime',
      body: 'A day counts as overtime when live check-out minus check-in is more than 9 hours. Times edited by a correction request are excluded.',
    },
  ];
  return (
    <div className="bg-white rounded-3xl border border-slate-200/80 p-6">
      <h3 className="font-extrabold text-slate-900">How badges work</h3>
      <div className="mt-4 grid md:grid-cols-3 gap-5">
        {rows.map(({ icon: Icon, color, title, body }) => (
          <div key={title} className="flex gap-3">
            <div className="p-2.5 rounded-xl h-fit" style={{ background: `${color}15`, color }}>
              <Icon className="w-4 h-4" />
            </div>
            <div>
              <p className="font-bold text-sm text-slate-900">{title}</p>
              <p className="text-xs text-slate-500 mt-1 leading-relaxed">{body}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

export default function Achievements() {
  const { data, loading, error } = useBadges();
  const [open, setOpen] = useState(null);
  const s = data?.stats || {};
  const badges = data?.badges || [];
  const streakBadges = badges.filter((b) => b.category === 'STREAK');
  const otBadges = badges.filter((b) => b.category === 'OVERTIME');
  const nextStreak = streakBadges.find((b) => !b.earned);
  const nextOT = otBadges.find((b) => !b.earned);
  const lit = (s.current_streak || 0) > 0 && s.streak_alive_today !== false;
  const otHours = (s.overtime_minutes || 0) / 60;

  return (
    <div className="space-y-7 max-w-6xl mx-auto">
      {/* Hero */}
      <section className="aurora rounded-[32px] p-7 md:p-9 text-white shadow-2xl">
        <span className="aurora-blob" />
        <div className="absolute inset-0 dot-grid-dark pointer-events-none" />
        <div className="relative flex flex-col lg:flex-row lg:items-end gap-8 justify-between">
          <div>
            <div className="flex items-center gap-2 text-white/70 text-xs font-extrabold tracking-[0.25em]">
              <Trophy className="w-4 h-4 text-amber-400" /> ACHIEVEMENTS
            </div>
            <h1 className="text-3xl md:text-4xl font-extrabold tracking-tight mt-3">Consistency, celebrated.</h1>
            <div className="flex items-end gap-4 mt-6">
              <StreakFlame size={64} lit={lit} />
              <span className="text-7xl font-extrabold leading-none tracking-tighter tabular-nums">{s.current_streak ?? 0}</span>
              <div className="pb-2">
                <p className="font-extrabold">day streak</p>
                <p className={`text-sm font-semibold ${s.streak_alive_today === false ? 'text-amber-300' : 'text-white/60'}`}>
                  {s.streak_alive_today === false ? 'Check in today to keep it alive!' : `Best: ${s.longest_streak ?? 0} days`}
                </p>
              </div>
            </div>
          </div>
          <div className="grid grid-cols-3 gap-3 lg:w-[460px]">
            {[
              { label: 'Overtime days', value: s.overtime_days ?? 0, icon: Moon },
              { label: 'Overtime hours', value: otHours >= 10 ? otHours.toFixed(0) : otHours.toFixed(1), icon: Clock3 },
              { label: 'Unlocked', value: `${data?.earned_count ?? 0}/${data?.total_count ?? 8}`, icon: Trophy },
            ].map(({ label, value, icon: Icon }) => (
              <div key={label} className="rounded-2xl bg-white/10 border border-white/15 p-4 backdrop-blur-sm">
                <Icon className="w-4 h-4 text-white/60" />
                <p className="text-2xl font-extrabold mt-2 tabular-nums">{value}</p>
                <p className="text-[11px] text-white/60 font-semibold">{label}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {error && !data && (
        <div className="flex items-center justify-between p-4 rounded-2xl bg-rose-50 border border-rose-200 text-rose-700 text-sm font-semibold">
          Could not load badges.
          <button onClick={() => loadBadges(true)} className="flex items-center gap-1.5 font-bold">
            <RefreshCw className="w-4 h-4" /> Retry
          </button>
        </div>
      )}

      {loading && !data ? (
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <div key={i} className="h-52 rounded-3xl bg-slate-200/60 animate-pulse" />
          ))}
        </div>
      ) : (
        data && (
          <>
            <div className="grid md:grid-cols-2 gap-4 stagger">
              <NextGoal badge={nextStreak} streak />
              <NextGoal badge={nextOT} streak={false} />
            </div>

            {[
              ['Streak badges', 'Every live check-in counts — weekends never break it.', streakBadges],
              ['Overtime badges', 'On site more than 9 hours (8h work + 1h break).', otBadges],
            ].map(([title, sub, list]) => (
              <section key={title}>
                <h2 className="text-lg font-extrabold tracking-tight text-slate-900">{title}</h2>
                <p className="text-xs text-slate-500 mb-4">{sub}</p>
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 stagger">
                  {list.map((b) => (
                    <BadgeCard key={b.code} badge={b} onOpen={setOpen} />
                  ))}
                </div>
              </section>
            ))}

            <Rules />
          </>
        )
      )}

      <BadgeDetail badge={open} onClose={() => setOpen(null)} featuredCode={data?.featured} />
    </div>
  );
}
