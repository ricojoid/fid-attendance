import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
  Users,
  User,
  LogOut,
  ShieldAlert,
  Megaphone,
  CalendarCheck,
  Clock,
  Sparkles,
  Activity,
  ChevronRight,
} from 'lucide-react';

export default function Layout({ children }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [timeStr, setTimeStr] = useState('');

  // Live real-time clock
  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      setTimeStr(
        now.toLocaleTimeString('en-US', {
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit',
          hour12: true,
        })
      );
    };
    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const getHeaderTitle = () => {
    switch (location.pathname) {
      case '/attendance':
        return 'Attendance Monitoring';
      case '/users':
        return 'User Management';
      case '/announcements':
        return 'Company Announcements';
      case '/profile':
        return 'Profile Settings';
      default:
        return 'Dashboard';
    }
  };

  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  };

  const navItems = [
    { path: '/attendance', label: 'Attendance', icon: CalendarCheck, reqAdmin: false },
    { path: '/users', label: 'User Directory', icon: Users, reqAdmin: true },
    { path: '/announcements', label: 'Announcements', icon: Megaphone, reqAdmin: false },
    { path: '/profile', label: 'My Profile', icon: User, reqAdmin: false },
  ];

  const roleUpper = (user?.role || '').toUpperCase();
  const deptUpper = (user?.department || '').toUpperCase();
  const canAdmin =
    roleUpper === 'SUPER_ADMIN' ||
    roleUpper === 'COUNTRY_HEAD' ||
    deptUpper === 'HUMAN RESOURCE' ||
    deptUpper === 'HUMAN RESOURCES' ||
    deptUpper === 'HR';

  return (
    <div className="min-h-screen flex bg-slate-50 relative overflow-hidden">
      {/* Ambient background glow orbs */}
      <div className="absolute top-0 right-1/4 w-[500px] h-[500px] bg-red-500/5 rounded-full blur-3xl pointer-events-none animate-float" />
      <div className="absolute bottom-10 right-10 w-[400px] h-[400px] bg-slate-400/5 rounded-full blur-3xl pointer-events-none animate-float delay-150" />

      {/* Sidebar */}
      <aside className="w-64 bg-slate-950 text-white flex flex-col justify-between border-r border-slate-800/80 shadow-2xl z-20 shrink-0">
        <div>
          {/* Logo Header */}
          <div className="p-5 border-b border-slate-800/70 flex items-center gap-3 bg-gradient-to-b from-slate-900/50 to-transparent">
            <div className="p-2 bg-white rounded-xl shadow-md ring-2 ring-white/10 animate-scale-in">
              <img src="/fujitsu.png" alt="Fujitsu Logo" className="w-6 h-6 object-contain" />
            </div>
            <div>
              <h1 className="font-extrabold text-sm tracking-tight text-white leading-tight flex items-center gap-1.5">
                FID Attendance
              </h1>
              <p className="text-[10px] font-semibold text-red-400 uppercase tracking-wider">
                Fujitsu Office
              </p>
            </div>
          </div>

          {/* Navigation */}
          <nav className="p-3.5 space-y-1.5">
            <p className="px-3 pt-2 pb-1 text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              Menu Navigation
            </p>
            {navItems
              .filter((item) => !item.reqAdmin || canAdmin)
              .map((item) => {
                const Icon = item.icon;
                const isActive = location.pathname === item.path;
                return (
                  <Link
                    key={item.path}
                    to={item.path}
                    className={`group relative flex items-center justify-between px-3.5 py-2.5 rounded-xl text-xs font-semibold transition-all duration-200 ${
                      isActive
                        ? 'bg-gradient-to-r from-red-600 to-red-700 text-white shadow-lg shadow-red-600/30 font-bold'
                        : 'text-slate-400 hover:bg-slate-900 hover:text-white hover:translate-x-1'
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <Icon className={`w-4 h-4 transition-transform duration-200 ${isActive ? 'scale-110' : 'group-hover:scale-110 text-slate-400 group-hover:text-red-400'}`} />
                      <span>{item.label}</span>
                    </div>
                    {isActive && (
                      <ChevronRight className="w-3.5 h-3.5 text-white/80 animate-pulse" />
                    )}
                  </Link>
                );
              })}
          </nav>
        </div>

        {/* User Card Footer */}
        <div className="p-3.5 border-t border-slate-800/80 bg-slate-900/40">
          <div className="flex items-center justify-between p-2 rounded-xl bg-slate-900/60 border border-slate-800/60 shadow-xs">
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-red-600 to-rose-500 text-white font-bold flex items-center justify-center text-xs shadow-md shrink-0">
                {user?.name?.charAt(0)?.toUpperCase() || 'U'}
              </div>
              <div className="truncate">
                <p className="text-xs font-bold text-white truncate leading-tight">{user?.name || 'User'}</p>
                <div className="flex items-center gap-1 mt-0.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                  <span className="text-[10px] text-slate-400 truncate">
                    {user?.role === 'SUPER_ADMIN' ? 'Super Admin' : user?.department || 'Employee'}
                  </span>
                </div>
              </div>
            </div>
            <button
              onClick={handleLogout}
              className="p-1.5 text-slate-400 hover:text-rose-400 hover:bg-slate-800 rounded-lg transition-all active:scale-90"
              title="Logout"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="flex-1 flex flex-col min-w-0 bg-dot-pattern">
        {/* Header Bar */}
        <header className="h-16 bg-white/85 backdrop-blur-md border-b border-slate-200/70 px-8 flex items-center justify-between shadow-xs sticky top-0 z-10">
          <div className="flex items-center gap-3">
            <div>
              <h2 className="font-bold text-slate-900 text-base tracking-tight animate-fade-in">
                {getHeaderTitle()}
              </h2>
              <p className="text-[11px] text-slate-500 hidden sm:block">
                {getGreeting()}, <span className="font-semibold text-slate-700">{user?.name}</span>
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            {/* Live Clock Chip */}
            {timeStr && (
              <div className="hidden md:flex items-center gap-2 px-3 py-1.5 bg-slate-100/80 rounded-xl border border-slate-200/60 text-xs font-mono font-medium text-slate-700 shadow-2xs">
                <Clock className="w-3.5 h-3.5 text-red-600 animate-pulse" />
                <span>{timeStr}</span>
              </div>
            )}

            {/* NIP Badge */}
            <div className="text-xs text-slate-700 bg-slate-100/90 px-3.5 py-1.5 rounded-xl font-medium border border-slate-200/70 shadow-2xs flex items-center gap-1.5">
              <Activity className="w-3 h-3 text-emerald-500" />
              NIP: <span className="font-bold text-slate-900 font-mono">{user?.nip || '-'}</span>
            </div>
          </div>
        </header>

        {/* Page Container */}
        <div className="p-8 flex-1 animate-fade-in">
          {children}
        </div>
      </main>
    </div>
  );
}


