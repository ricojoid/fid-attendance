import React from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Users, User, LogOut, Building2, ShieldAlert } from 'lucide-react';

export default function Layout({ children }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="min-h-screen flex bg-slate-50">
      {/* Sidebar */}
      <aside className="w-64 bg-slate-900 text-white flex flex-col justify-between border-r border-slate-800">
        <div>
          <div className="p-6 border-b border-slate-800 flex items-center gap-3">
            <div className="p-2 bg-blue-600 rounded-lg">
              <Building2 className="w-5 h-5 text-white" />
            </div>
            <div>
              <h1 className="font-bold text-base tracking-wide leading-tight">FID Attendance</h1>
              <p className="text-xs text-slate-400">Office Management</p>
            </div>
          </div>

          <nav className="p-4 space-y-1">
            {user?.role === 'SUPER_ADMIN' && (
              <Link
                to="/users"
                className={`flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-colors ${
                  location.pathname === '/users'
                    ? 'bg-blue-600 text-white'
                    : 'text-slate-300 hover:bg-slate-800 hover:text-white'
                }`}
              >
                <Users className="w-4 h-4" />
                User Management
              </Link>
            )}

            <Link
              to="/profile"
              className={`flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-colors ${
                location.pathname === '/profile'
                  ? 'bg-blue-600 text-white'
                  : 'text-slate-300 hover:bg-slate-800 hover:text-white'
              }`}
            >
              <User className="w-4 h-4" />
              Edit Profile
            </Link>
          </nav>
        </div>

        {/* User Footer */}
        <div className="p-4 border-t border-slate-800">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-full bg-blue-500/20 text-blue-400 font-semibold flex items-center justify-center border border-blue-500/30 text-sm">
                {user?.name?.charAt(0) || 'U'}
              </div>
              <div className="truncate">
                <p className="text-sm font-medium text-white truncate">{user?.name}</p>
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
              className="p-2 text-slate-400 hover:text-rose-400 hover:bg-slate-800 rounded-lg transition-colors"
              title="Logout"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col">
        <header className="h-16 bg-white border-b border-slate-200 px-8 flex items-center justify-between">
          <h2 className="font-semibold text-slate-800 text-lg">
            {location.pathname === '/users' ? 'User Management' : 'My Profile'}
          </h2>
          <div className="text-xs text-slate-500 bg-slate-100 px-3 py-1.5 rounded-full font-medium">
            NIP: <span className="font-bold text-slate-700">{user?.nip}</span>
          </div>
        </header>

        <div className="p-8 flex-1">
          {children}
        </div>
      </main>
    </div>
  );
}
