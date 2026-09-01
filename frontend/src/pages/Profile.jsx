import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import api from '../api/client';
import {
  User,
  Mail,
  Building2,
  Lock,
  CheckCircle2,
  AlertCircle,
  Save,
  Calendar,
  Shield,
  ShieldCheck,
  Eye,
  EyeOff,
  BadgeCheck,
  RotateCcw,
  UserCheck,
  Hash,
  Layers,
} from 'lucide-react';

export default function Profile() {
  const { user, updateUserProfile } = useAuth();
  const [name, setName] = useState(user?.name || '');
  const [department, setDepartment] = useState(user?.department || 'App Dev & Data AI');
  const [birthDate, setBirthDate] = useState(user?.birth_date || '');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [success, setSuccess] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (user) {
      setName(user.name || '');
      setDepartment(user.department || 'App Dev & Data AI');
      setBirthDate(user.birth_date || '');
    }
  }, [user]);

  const handleReset = () => {
    setName(user?.name || '');
    setDepartment(user?.department || 'App Dev & Data AI');
    setBirthDate(user?.birth_date || '');
    setPassword('');
    setConfirmPassword('');
    setError('');
    setSuccess('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSuccess('');
    setError('');

    if (password) {
      if (password.length < 6) {
        setError('New password must be at least 6 characters.');
        return;
      }
      if (password !== confirmPassword) {
        setError('New password and confirm password do not match.');
        return;
      }
    }

    setLoading(true);
    try {
      const payload = {
        name,
        department,
        birth_date: birthDate,
      };
      if (password) {
        payload.password = password;
      }

      const res = await api.put('/profile', payload);
      updateUserProfile(res.data.user);
      setSuccess('Profile updated successfully.');
      setPassword('');
      setConfirmPassword('');
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to update profile. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const getRoleBadge = (role) => {
    switch (role) {
      case 'SUPER_ADMIN':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-rose-500/10 text-rose-400 border border-rose-500/30 shadow-xs">
            <ShieldCheck className="w-3.5 h-3.5" /> Super Admin
          </span>
        );
      case 'COUNTRY_HEAD':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-amber-500/10 text-amber-400 border border-amber-500/30 shadow-xs">
            <UserCheck className="w-3.5 h-3.5" /> Country Head
          </span>
        );
      case 'MANAGER':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-purple-500/10 text-purple-400 border border-purple-500/30 shadow-xs">
            <Layers className="w-3.5 h-3.5" /> Manager
          </span>
        );
      case 'DEPARTMENT_HEAD':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-indigo-500/10 text-indigo-400 border border-indigo-500/30 shadow-xs">
            <Building2 className="w-3.5 h-3.5" /> Dept Head
          </span>
        );
      case 'EMPLOYEE':
      default:
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-slate-800 text-slate-300 border border-slate-700/60 shadow-xs">
            <Shield className="w-3.5 h-3.5" /> Employee
          </span>
        );
    }
  };

  return (
    <div className="max-w-6xl mx-auto space-y-6 animate-fade-in pb-12">
      {/* Header Banner */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-6 rounded-2xl border border-slate-200/80 shadow-xs">
        <div>
          <h1 className="text-2xl font-extrabold text-slate-900 tracking-tight">
            Profile Settings
          </h1>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 px-3.5 py-1.5 bg-emerald-50 text-emerald-700 border border-emerald-200/80 rounded-xl text-xs font-semibold">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            Active Account
          </div>
        </div>
      </div>

      {/* Success / Error Alerts */}
      {success && (
        <div className="p-4 bg-emerald-50 border border-emerald-200/90 text-emerald-800 rounded-2xl text-sm flex items-center justify-between shadow-xs animate-slide-down">
          <div className="flex items-center gap-3">
            <div className="p-1 bg-emerald-100 rounded-lg text-emerald-700">
              <CheckCircle2 className="w-5 h-5" />
            </div>
            <div>
              <p className="font-semibold text-emerald-900">{success}</p>
            </div>
          </div>
          <button
            onClick={() => setSuccess('')}
            className="text-emerald-600 hover:text-emerald-900 text-xs font-semibold px-2 py-1"
          >
            Dismiss
          </button>
        </div>
      )}

      {error && (
        <div className="p-4 bg-rose-50 border border-rose-200 text-rose-800 rounded-2xl text-sm flex items-center justify-between shadow-xs animate-slide-down">
          <div className="flex items-center gap-3">
            <div className="p-1 bg-rose-100 rounded-lg text-rose-700">
              <AlertCircle className="w-5 h-5" />
            </div>
            <div>
              <p className="font-semibold text-rose-900">{error}</p>
            </div>
          </div>
          <button
            onClick={() => setError('')}
            className="text-rose-600 hover:text-rose-900 text-xs font-semibold px-2 py-1"
          >
            Dismiss
          </button>
        </div>
      )}

      {/* Main Grid: Left Identity Card + Right Form Cards */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Profile Overview Card */}
        <div className="lg:col-span-4 space-y-6">
          <div className="bg-slate-950 rounded-2xl border border-slate-800 shadow-xl overflow-hidden text-white flex flex-col justify-between">
            {/* Dark Sleek Fujitsu Gradient Banner */}
            <div className="relative h-28 bg-gradient-to-br from-slate-900 via-slate-950 to-red-950 p-4 flex justify-between items-start border-b border-slate-800/80">
              <div className="absolute inset-0 opacity-10 bg-[radial-gradient(#e60012_1px,transparent_1px)] [background-size:12px_12px]" />
              <div className="relative flex items-center gap-2 bg-black/40 backdrop-blur-md px-2.5 py-1 rounded-lg border border-white/10 text-[11px] font-medium text-slate-300">
                <BadgeCheck className="w-3.5 h-3.5 text-red-500" />
                FID Member
              </div>
              <div className="relative">
                {getRoleBadge(user?.role)}
              </div>
            </div>

            {/* Avatar & Summary */}
            <div className="px-6 pb-6 pt-0 relative">
              <div className="-mt-12 mb-4 flex items-end justify-between">
                <div className="w-20 h-20 rounded-2xl bg-slate-900 p-1 ring-4 ring-slate-950 shadow-2xl relative">
                  <div className="w-full h-full rounded-xl bg-gradient-to-tr from-red-600 to-rose-500 text-white font-extrabold text-2xl flex items-center justify-center shadow-inner">
                    {user?.name?.charAt(0)?.toUpperCase() || 'U'}
                  </div>
                  <span className="absolute bottom-1 right-1 w-3.5 h-3.5 rounded-full bg-emerald-500 ring-2 ring-slate-900" />
                </div>
              </div>

              <div>
                <h2 className="text-lg font-bold text-white tracking-tight">{user?.name || 'User'}</h2>
                <p className="text-xs text-slate-400 font-mono mt-0.5">{user?.email || '-'}</p>
              </div>

              {/* Info Badges & Details */}
              <div className="mt-6 pt-6 border-t border-slate-800/80 space-y-3">
                <div className="flex items-center justify-between text-xs py-1">
                  <span className="text-slate-400 flex items-center gap-2">
                    <Hash className="w-3.5 h-3.5 text-red-400" /> Employee ID
                  </span>
                  <span className="font-mono font-semibold text-white bg-slate-900 px-2 py-0.5 rounded border border-slate-800">
                    {user?.nip || '-'}
                  </span>
                </div>

                <div className="flex items-center justify-between text-xs py-1">
                  <span className="text-slate-400 flex items-center gap-2">
                    <Building2 className="w-3.5 h-3.5 text-red-400" /> Department
                  </span>
                  <span className="font-medium text-slate-200">
                    {user?.department || 'General'}
                  </span>
                </div>

                <div className="flex items-center justify-between text-xs py-1">
                  <span className="text-slate-400 flex items-center gap-2">
                    <UserCheck className="w-3.5 h-3.5 text-red-400" /> Approver
                  </span>
                  <span className="font-medium text-slate-200">
                    {user?.approver_name || 'Dina (Default)'}
                  </span>
                </div>

                <div className="flex items-center justify-between text-xs py-1">
                  <span className="text-slate-400 flex items-center gap-2">
                    <Calendar className="w-3.5 h-3.5 text-red-400" /> Date of Birth
                  </span>
                  <span className="font-medium text-slate-200">
                    {user?.birth_date || '-'}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Right Column: Edit Profile Form */}
        <div className="lg:col-span-8">
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Section 1: Personal Information */}
            <div className="bg-white rounded-2xl border border-slate-200/80 shadow-xs p-6 space-y-6">
              <div className="flex items-center justify-between border-b border-slate-100 pb-4">
                <div className="flex items-center gap-3">
                  <div className="p-2 bg-red-50 rounded-xl text-red-600 border border-red-100">
                    <User className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="font-bold text-slate-900 text-base">Personal Information</h3>
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                {/* NIP (Read Only) */}
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider">
                      Employee ID (NIP)
                    </label>
                    <span className="text-[10px] bg-slate-100 text-slate-500 font-semibold px-2 py-0.5 rounded border border-slate-200">
                      Read-Only
                    </span>
                  </div>
                  <div className="relative">
                    <Hash className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type="text"
                      disabled
                      value={user?.nip || ''}
                      className="w-full pl-10 pr-4 py-2.5 bg-slate-50/80 border border-slate-200 rounded-xl text-sm font-mono text-slate-500 cursor-not-allowed select-none"
                    />
                  </div>
                </div>

                {/* Email (Read Only) */}
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider">
                      Company Email
                    </label>
                    <span className="text-[10px] bg-slate-100 text-slate-500 font-semibold px-2 py-0.5 rounded border border-slate-200">
                      Read-Only
                    </span>
                  </div>
                  <div className="relative">
                    <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type="email"
                      disabled
                      value={user?.email || ''}
                      className="w-full pl-10 pr-4 py-2.5 bg-slate-50/80 border border-slate-200 rounded-xl text-sm text-slate-500 cursor-not-allowed select-none"
                    />
                  </div>
                </div>

                {/* Full Name */}
                <div className="md:col-span-2">
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                    Full Name <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <User className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type="text"
                      required
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      placeholder="Enter full name"
                      className="w-full pl-10 pr-4 py-2.5 bg-white border border-slate-300 rounded-xl text-sm font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-red-500/20 focus:border-red-600 transition-all shadow-2xs"
                    />
                  </div>
                </div>

                {/* Department */}
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                    Department
                  </label>
                  <div className="relative">
                    <Building2 className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                    <select
                      value={department}
                      onChange={(e) => setDepartment(e.target.value)}
                      className="w-full pl-10 pr-4 py-2.5 bg-white border border-slate-300 rounded-xl text-sm font-medium text-slate-800 focus:outline-none focus:ring-2 focus:ring-red-500/20 focus:border-red-600 transition-all shadow-2xs"
                    >
                      {MASTER_DEPARTMENTS.map((dept) => (
                        <option key={dept} value={dept}>
                          {dept}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>

                {/* Date of Birth */}
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                    Date of Birth
                  </label>
                  <div className="relative">
                    <Calendar className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type="date"
                      value={birthDate}
                      onChange={(e) => setBirthDate(e.target.value)}
                      className="w-full pl-10 pr-4 py-2.5 bg-white border border-slate-300 rounded-xl text-sm font-medium text-slate-800 focus:outline-none focus:ring-2 focus:ring-red-500/20 focus:border-red-600 transition-all shadow-2xs"
                    />
                  </div>
                </div>
              </div>
            </div>

            {/* Section 2: Password */}
            <div className="bg-white rounded-2xl border border-slate-200/80 shadow-xs p-6 space-y-6">
              <div className="flex items-center justify-between border-b border-slate-100 pb-4">
                <div className="flex items-center gap-3">
                  <div className="p-2 bg-slate-100 rounded-xl text-slate-800 border border-slate-200">
                    <Lock className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="font-bold text-slate-900 text-base">Change Password</h3>
                  </div>
                </div>
                <span className="text-xs text-slate-400 font-medium">Optional</span>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                {/* New Password */}
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                    New Password
                  </label>
                  <div className="relative">
                    <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type={showPassword ? 'text' : 'password'}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="Min. 6 characters"
                      className="w-full pl-10 pr-10 py-2.5 bg-white border border-slate-300 rounded-xl text-sm font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-red-500/20 focus:border-red-600 transition-all shadow-2xs"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 p-1"
                    >
                      {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                </div>

                {/* Confirm Password */}
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                    Confirm New Password
                  </label>
                  <div className="relative">
                    <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type={showConfirmPassword ? 'text' : 'password'}
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      placeholder="Re-enter password"
                      className={`w-full pl-10 pr-10 py-2.5 bg-white border rounded-xl text-sm font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 transition-all shadow-2xs ${
                        confirmPassword && password !== confirmPassword
                          ? 'border-rose-300 focus:ring-rose-500/20 focus:border-rose-500'
                          : 'border-slate-300 focus:ring-red-500/20 focus:border-red-600'
                      }`}
                    />
                    <button
                      type="button"
                      onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 p-1"
                    >
                      {showConfirmPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                  {confirmPassword && password !== confirmPassword && (
                    <p className="text-[11px] text-rose-500 mt-1 font-medium flex items-center gap-1">
                      <AlertCircle className="w-3 h-3" /> Passwords do not match
                    </p>
                  )}
                </div>
              </div>
            </div>

            {/* Bottom Actions Bar */}
            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                onClick={handleReset}
                disabled={loading}
                className="px-5 py-2.5 bg-white hover:bg-slate-100 text-slate-700 font-semibold text-sm rounded-xl border border-slate-300 transition-all flex items-center gap-2 active:scale-95 disabled:opacity-50"
              >
                <RotateCcw className="w-4 h-4" />
                Reset
              </button>

              <button
                type="submit"
                disabled={loading}
                className="px-7 py-2.5 bg-red-600 hover:bg-red-700 active:bg-red-800 text-white font-bold text-sm rounded-xl flex items-center gap-2.5 shadow-lg shadow-red-600/25 transition-all duration-150 btn-bounce disabled:opacity-50"
              >
                {loading ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    <span>Saving...</span>
                  </>
                ) : (
                  <>
                    <Save className="w-4 h-4" />
                    <span>Save Changes</span>
                  </>
                )}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}



