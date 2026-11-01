import React, { memo, useEffect, useState } from 'react';
import { NavLink, useLocation, useNavigate } from 'react-router-dom';
import { Users, User, LogOut, Megaphone, CalendarCheck, Clock, Trophy, Inbox, Menu, X, MapPinned, Newspaper } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { getPendingApprovals, markBadgesSeen } from '../api/client';
import { clearNewBadges, loadBadges, useBadges } from '../hooks/useBadges';
import { StreakFlame } from './BadgeMedal';
import BadgeCelebration from './BadgeCelebration';
import AvatarFrame from './AvatarFrame';
import ThemeDecor from './ThemeDecor';
import { THEMES } from '../themes';
import { useApplyTheme } from '../hooks/useTheme';
import { useLiveEvents } from '../hooks/useLiveEvents';

// The clock lives in its own component so its 1s tick re-renders only itself,
// never the sidebar or the page.
const LiveClock = memo(function LiveClock() {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const id = setInterval(() => {
      if (document.visibilityState === 'visible') setNow(new Date());
    }, 1000);
    return () => clearInterval(id);
  }, []);
  return (
    <div className="hidden md:flex items-center gap-2 px-3 py-1.5 bg-white rounded-xl border border-slate-200/80 text-xs font-semibold text-slate-700 tabular-nums">
      <Clock className="w-3.5 h-3.5 text-brand-500" />
      {now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
    </div>
  );
});

const TITLES = {
  '/attendance': ['Attendance Monitoring', 'Live presence across your scope'],
  '/approvals': ['Approvals', 'Leave & correction requests routed to you'],
  '/map': ['Location Map', 'Where your team checked in and out'],
  '/timeline': ['Timeline', 'Share what you did today'],
  '/achievements': ['Achievements', 'Streaks, overtime and badges'],
  '/users': ['User Directory', 'Manage employees and reporting lines'],
  '/announcements': ['Announcements', 'Company news and updates'],
  '/profile': ['My Profile', 'Personal details and security'],
};

function isAdmin(user) {
  const role = (user?.role || '').toUpperCase();
  const dept = (user?.department || '').toUpperCase();
  return role === 'SUPER_ADMIN' || role === 'COUNTRY_HEAD' || ['HUMAN RESOURCE', 'HUMAN RESOURCES', 'HR'].includes(dept);
}

function greeting() {
  const h = new Date().getHours();
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

export default function Layout({ children }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [pending, setPending] = useState(0);
  const [celebrate, setCelebrate] = useState(null);
  const { data: badges } = useBadges();
  useApplyTheme(user?.app_theme);
  useLiveEvents(!!user);
  const [liveToast, setLiveToast] = useState(null);

  // Toast for announcements published while the dashboard is open.
  useEffect(() => {
    let t;
    const onAnn = (e) => {
      if (e.detail?.action !== 'created') return;
      setLiveToast(e.detail.announcement);
      clearTimeout(t);
      t = setTimeout(() => setLiveToast(null), 6000);
    };
    window.addEventListener('live:announcement', onAnn);
    return () => {
      window.removeEventListener('live:announcement', onAnn);
      clearTimeout(t);
    };
  }, []);
  const decor = THEMES[user?.app_theme]?.decor;

  // Pending approvals count for the nav badge (refreshed on route change, cheap).
  useEffect(() => {
    let alive = true;
    getPendingApprovals()
      .then((list) => alive && setPending(list.length))
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [location.pathname]);

  useEffect(() => setMobileOpen(false), [location.pathname]);

  // Celebrate newly unlocked badges once, wherever the user lands.
  useEffect(() => {
    if (badges?.newly_unlocked?.length && !celebrate) setCelebrate(badges.newly_unlocked);
  }, [badges, celebrate]);

  const closeCelebration = async () => {
    const codes = (celebrate || []).map((b) => b.code);
    setCelebrate(null);
    clearNewBadges();
    try {
      await markBadgesSeen(codes);
    } finally {
      loadBadges(true);
    }
  };

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const admin = isAdmin(user);
  const nav = [
    { path: '/attendance', label: 'Attendance', icon: CalendarCheck },
    { path: '/timeline', label: 'Timeline', icon: Newspaper },
    { path: '/map', label: 'Location Map', icon: MapPinned },
    { path: '/approvals', label: 'Approvals', icon: Inbox, count: pending },
    { path: '/achievements', label: 'Achievements', icon: Trophy },
    { path: '/users', label: 'User Directory', icon: Users, admin: true },
    { path: '/announcements', label: 'Announcements', icon: Megaphone },
    { path: '/profile', label: 'My Profile', icon: User },
  ].filter((i) => !i.admin || admin);

  const [title, subtitle] = TITLES[location.pathname] || ['Dashboard', ''];
  const streak = badges?.stats?.current_streak ?? 0;
  const lit = streak > 0 && badges?.stats?.streak_alive_today !== false;
  const avatar = user?.avatar_url;

  const sidebar = (
    <aside className="aurora w-72 h-full flex flex-col text-white">
      <span className="aurora-blob" />
      <div className="absolute inset-0 dot-grid-dark pointer-events-none" />
      <div className="relative p-6 flex items-center gap-3">
        <div className="p-2 bg-white rounded-2xl shadow-lg">
          <img src="/fujitsu.png" alt="Fujitsu" className="w-7 h-7 object-contain" />
        </div>
        <div>
          <p className="font-extrabold tracking-tight leading-tight">FID Attendance</p>
          <p className="text-[10px] font-bold text-brand-400 tracking-[0.2em]">FUJITSU OFFICE</p>
        </div>
      </div>

      {/* Streak card */}
      <NavLink
        to="/achievements"
        className="relative mx-4 mb-4 p-4 rounded-2xl bg-white/[0.07] border border-white/10 hover:bg-white/[0.12] transition-colors flex items-center gap-3"
      >
        <StreakFlame size={34} lit={lit} />
        <div className="min-w-0">
          <p className="text-2xl font-extrabold leading-none tabular-nums">{streak}</p>
          <p className="text-[11px] text-white/60 font-semibold mt-1">
            {badges?.stats?.streak_alive_today === false ? 'Check in to keep your streak' : 'day streak'}
          </p>
        </div>
        <div className="ml-auto text-right">
          <p className="text-sm font-extrabold tabular-nums">
            {badges?.earned_count ?? 0}/{badges?.total_count ?? 8}
          </p>
          <p className="text-[10px] text-white/50 font-semibold">badges</p>
        </div>
      </NavLink>

      <nav className="relative px-3 space-y-1 flex-1">
        <p className="px-3 pb-2 text-[10px] font-extrabold text-white/40 tracking-[0.2em]">MENU</p>
        {nav.map(({ path, label, icon: Icon, count }) => (
          <NavLink
            key={path}
            to={path}
            className={({ isActive }) =>
              `group relative flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-sm font-semibold transition-all duration-200 ${
                isActive ? 'bg-white text-slate-900 shadow-lg' : 'text-white/65 hover:text-white hover:bg-white/[0.07]'
              }`
            }
          >
            {({ isActive }) => (
              <>
                <Icon className={`w-[18px] h-[18px] transition-transform group-hover:scale-110 ${isActive ? 'text-brand-500' : ''}`} />
                {label}
                {count > 0 && (
                  <span className="ml-auto min-w-[22px] h-[22px] px-1.5 rounded-full bg-brand-500 text-white text-[11px] font-extrabold flex items-center justify-center">
                    {count > 99 ? '99+' : count}
                  </span>
                )}
              </>
            )}
          </NavLink>
        ))}
      </nav>

      <div className="relative p-4">
        <div className="flex items-center gap-3 p-3 rounded-2xl bg-white/[0.07] border border-white/10">
          <AvatarFrame frame={user?.avatar_frame} src={avatar} name={user?.name} size={40} />
          <div className="min-w-0 flex-1">
            <p className="text-sm font-bold truncate">{user?.name || 'User'}</p>
            <p className="text-[11px] text-white/50 truncate">
              {user?.role === 'SUPER_ADMIN' ? 'Super Admin' : user?.department || 'Employee'}
            </p>
          </div>
          <button
            onClick={handleLogout}
            title="Sign out"
            className="p-2 rounded-xl text-white/60 hover:text-white hover:bg-white/10 active:scale-90 transition-all"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </aside>
  );

  return (
    <div className="min-h-screen flex" style={{ background: 'rgb(var(--bg))' }}>
      {/* Desktop sidebar */}
      <div className="hidden lg:block fixed inset-y-0 left-0 z-30 shadow-2xl">{sidebar}</div>

      {/* Mobile drawer */}
      <div className={`lg:hidden fixed inset-0 z-40 ${mobileOpen ? '' : 'pointer-events-none'}`}>
        <div
          className={`absolute inset-0 bg-slate-950/50 transition-opacity duration-300 ${mobileOpen ? 'opacity-100' : 'opacity-0'}`}
          onClick={() => setMobileOpen(false)}
        />
        <div
          className={`absolute inset-y-0 left-0 transition-transform duration-300 ease-emphasized ${
            mobileOpen ? 'translate-x-0' : '-translate-x-full'
          }`}
        >
          {sidebar}
        </div>
      </div>

      <main className="flex-1 min-w-0 lg:ml-72 flex flex-col">
        <header
          className="sticky top-0 z-20 h-16 px-4 md:px-8 flex items-center gap-3 backdrop-blur-md border-b border-slate-200/60"
          style={{ background: 'rgb(var(--bg) / 0.8)' }}
        >
          <button className="lg:hidden p-2 -ml-1 rounded-xl hover:bg-white" onClick={() => setMobileOpen((v) => !v)}>
            {mobileOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
          </button>
          <div className="min-w-0">
            <h2 key={title} className="font-extrabold text-slate-900 tracking-tight animate-fade-in truncate">
              {title}
            </h2>
            <p className="text-[11px] text-slate-500 hidden sm:block truncate">
              {greeting()}, <span className="font-semibold text-slate-700">{user?.name}</span>
              {subtitle ? ` · ${subtitle}` : ''}
            </p>
          </div>
          <div className="ml-auto flex items-center gap-2.5">
            <LiveClock />
            <div className="text-xs text-slate-600 bg-white px-3 py-1.5 rounded-xl border border-slate-200/80 font-semibold">
              NIP <span className="font-extrabold text-slate-900">{user?.nip || '-'}</span>
            </div>
          </div>
        </header>

        <div key={location.pathname} className="p-4 md:p-8 flex-1 animate-fade-in">
          {children}
        </div>
      </main>

      <ThemeDecor decor={decor} />
      {liveToast && (
        <button
          onClick={() => {
            setLiveToast(null);
            navigate('/announcements');
          }}
          className="fixed top-4 right-4 z-[80] w-[360px] max-w-[calc(100vw-2rem)] text-left rounded-2xl shadow-2xl live-toast"
        >
          <div className="aurora rounded-2xl p-4 text-white">
          <span className="aurora-blob" />
          <div className="relative flex gap-3">
            <div className="w-10 h-10 shrink-0 rounded-xl bg-gradient-to-br from-brand-400 to-brand-700 flex items-center justify-center text-lg">
              {liveToast.category === 'IMPORTANT' ? '❗' : '📢'}
            </div>
            <div className="min-w-0">
              <p className="text-[10px] font-extrabold tracking-[0.15em] text-amber-300 flex items-center gap-1.5">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" /> NEW ANNOUNCEMENT · LIVE
              </p>
              <p className="font-extrabold truncate">{liveToast.title}</p>
              <p className="text-xs text-white/60 line-clamp-2">{liveToast.content}</p>
            </div>
          </div>
          </div>
        </button>
      )}
      {celebrate && <BadgeCelebration badges={celebrate} onClose={closeCelebration} avatar={avatar} />}
    </div>
  );
}
