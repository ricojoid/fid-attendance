import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Lock, Mail, AlertCircle, ShieldCheck } from 'lucide-react';

export default function Login() {
  const [email, setEmail] = useState('admin@office.com');
  const [password, setPassword] = useState('Admin123!');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const user = await login(email, password);
      if (user.role === 'SUPER_ADMIN') {
        navigate('/users');
      } else {
        navigate('/profile');
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to sign in. Please check your credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4 relative overflow-hidden">
      {/* Dynamic Background Animated Glow Blobs */}
      <div className="absolute -top-32 -left-32 w-96 h-96 bg-red-600/20 rounded-full blur-3xl animate-float pointer-events-none" />
      <div className="absolute -bottom-32 -right-32 w-96 h-96 bg-red-900/30 rounded-full blur-3xl animate-float delay-300 pointer-events-none" />

      <div className="w-full max-w-md bg-white rounded-2xl shadow-2xl border border-slate-100 overflow-hidden animate-slide-up relative z-10">
        {/* Fujitsu Header Section */}
        <div className="bg-gradient-to-br from-red-600 via-red-600 to-red-700 p-8 text-white text-center relative overflow-hidden">
          <div className="absolute top-0 right-0 w-32 h-32 bg-white/5 rounded-full blur-xl pointer-events-none" />
          
          <div className="inline-flex p-3 bg-white rounded-xl mb-3 shadow-lg shadow-black/10 animate-scale-in">
            <img src="/fujitsu.png" alt="Fujitsu Logo" className="h-8 object-contain" />
          </div>
          <h1 className="text-2xl font-extrabold tracking-tight">FID Attendance System</h1>
          <p className="text-red-100 text-xs font-medium mt-1">Fujitsu Official Attendance Management</p>
        </div>

        <form onSubmit={handleSubmit} className="p-8 space-y-5 animate-fade-in delay-100">
          {error && (
            <div className="p-3.5 bg-rose-50 border border-rose-200 text-rose-600 rounded-xl text-xs font-medium flex items-center gap-2.5 animate-slide-down">
              <AlertCircle className="w-4 h-4 shrink-0 text-rose-500" />
              <span>{error}</span>
            </div>
          )}

          <div>
            <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-2">
              Email Address
            </label>
            <div className="relative group">
              <Mail className="w-5 h-5 text-slate-400 group-focus-within:text-red-600 transition-colors absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full pl-11 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-red-500/30 focus:border-red-500 focus:bg-white transition-all duration-200"
                placeholder="name@company.com"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-2">
              Password
            </label>
            <div className="relative group">
              <Lock className="w-5 h-5 text-slate-400 group-focus-within:text-red-600 transition-colors absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full pl-11 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-red-500/30 focus:border-red-500 focus:bg-white transition-all duration-200"
                placeholder="••••••••"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-red-600 hover:bg-red-700 active:bg-red-800 text-white font-semibold rounded-xl text-sm transition-all duration-200 shadow-lg shadow-red-600/25 btn-bounce disabled:opacity-50 flex items-center justify-center gap-2"
          >
            {loading ? (
              <span className="flex items-center gap-2">
                <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                Signing in...
              </span>
            ) : (
              <>
                <ShieldCheck className="w-4 h-4" />
                Sign In
              </>
            )}
          </button>

          <div className="pt-4 border-t border-slate-100 text-center">
            <p className="text-xs text-slate-500">
              Default Super Admin: <span className="font-semibold text-slate-700">admin@office.com</span> / <span className="font-semibold text-slate-700">Admin123!</span>
            </p>
          </div>
        </form>
      </div>
    </div>
  );
}

