import React from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Users, User, LogOut, ShieldAlert, Megaphone, CalendarCheck } from 'lucide-react';

export default function Layout({ children }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

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
        return 'My Profile';
      default:
        return 'Dashboard';
    }
  };

  return (
    <div className="min-h-screen flex bg-slate-50">
      {/* Sidebar */}
      <aside className="w-64 bg-slate-950 text-white flex flex-col justify-between border-r border-slate-800 shadow-xl z-20">
        <div>
          <div className="p-6 border-b border-slate-800/80 flex items-center gap-3">
            <div className="p-1.5 bg-white rounded-xl shadow-md animate-scale-in">
              <img src="/fujitsu.png" alt="Fujitsu Logo" className="w-6 h-6 object-contain" />
            </div>
            <div>
              <h1 className="font-extrabold text-base tracking-tight text-white leading-tight">FID Attendance</h1>
              <p className="text-[11px] text-red-400 font-medium">Fujitsu Office System</p>
            </div>
          </div>

          <nav className="p-4 space-y-1.5">
            <Link
              to="/attendance"
              className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all duration-200 ${
                location.pathname === '/attendance'
                  ? 'bg-red-600 text-white shadow-lg shadow-red-600/30'
                  : 'text-slate-400 hover:bg-slate-900 hover:text-white hover:translate-x-1'
              }`}
            >
              <CalendarCheck className="w-4 h-4" />
              Attendance Monitoring
            </Link>

            {user?.role === 'SUPER_ADMIN' && (
              <Link
                to="/users"
                className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all duration-200 ${
                  location.pathname === '/users'
                    ? 'bg-red-600 text-white shadow-lg shadow-red-600/30'
                    : 'text-slate-400 hover:bg-slate-900 hover:text-white hover:translate-x-1'
                }`}
              >
                <Users className="w-4 h-4" />
                User Management
              </Link>
            )}

            <Link
              to="/announcements"
              className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all duration-200 ${
                location.pathname === '/announcements'
                  ? 'bg-red-600 text-white shadow-lg shadow-red-600/30'
                  : 'text-slate-400 hover:bg-slate-900 hover:text-white hover:translate-x-1'
              }`}
            >
              <Megaphone className="w-4 h-4" />
              Announcements
            </Link>

            <Link
              to="/profile"
              className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all duration-200 ${
                location.pathname === '/profile'
                  ? 'bg-red-600 text-white shadow-lg shadow-red-600/30'
                  : 'text-slate-400 hover:bg-slate-900 hover:text-white hover:translate-x-1'
              }`}
            >
              <User className="w-4 h-4" />
              Edit Profile
            </Link>
          </nav>
        </div>

        {/* User Footer */}
        <div className="p-4 border-t border-slate-800/80 bg-slate-900/50">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-full bg-red-600/20 text-red-400 font-bold flex items-center justify-center border border-red-500/30 text-sm shadow-sm">
                {user?.name?.charAt(0) || 'U'}
              </div>
              <div className="truncate">
                <p className="text-sm font-semibold text-white truncate">{user?.name}</p>
                <span className="inline-flex items-center gap-1 text-[11px] font-medium text-slate-400">
                  {user?.role === 'SUPER_ADMIN' ? (
                    <span className="text-amber-400 font-semibold flex items-center gap-1">
                      <ShieldAlert className="w-3 h-3" /> Admin
                    </span>
                  ) : (
                    'Employee'
                  )}
                </span>
              </div>
            </div>
            <button
              onClick={handleLogout}
              className="p-2 text-slate-400 hover:text-rose-400 hover:bg-slate-800 rounded-xl transition-all duration-200 active:scale-90"
              title="Logout"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col min-w-0">
        <header className="h-16 bg-white border-b border-slate-200/80 px-8 flex items-center justify-between shadow-xs sticky top-0 z-10">
          <h2 className="font-bold text-slate-800 text-lg tracking-tight animate-fade-in">
            {getHeaderTitle()}
          </h2>
          <div className="text-xs text-slate-600 bg-slate-100 px-3.5 py-1.5 rounded-full font-medium border border-slate-200/60 shadow-xs flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            NIP: <span className="font-bold text-slate-900">{user?.nip}</span>
          </div>
        </header>

        <div className="p-8 flex-1 animate-fade-in">
          {children}
        </div>
      </main>
    </div>
  );
}

