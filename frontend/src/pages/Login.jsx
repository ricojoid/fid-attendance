import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Lock, Mail, AlertCircle, Eye, EyeOff, ArrowRight } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import Mascot, { DoodleCalendar, DoodleCoffee, DoodleHeart, DoodleMedal, DoodlePlane, DoodleSparkle } from '../components/Mascot';
import { Confetti } from '../components/BadgeCelebration';

const LINES = {
  idle: ["Hi! I'm Tiki ⏰", 'Ready to start the day?'],
  email: ['Ooh, who are you?', "Let me read that…"],
  password: ["I'm not looking! 🙈", 'Your secret is safe.'],
  peek: ['Just a tiny peek… 👀', 'Oops, I saw nothing!'],
  error: ['Hmm, that didn’t work 😢', 'Double-check and try again?'],
  success: ['Yay! Welcome back! 🎉', 'Let’s make today count!'],
};

function greetingLine() {
  const h = new Date().getHours();
  if (h < 11) return 'Good morning ☀️';
  if (h < 15) return 'Good afternoon 🌤️';
  if (h < 19) return 'Good evening 🌇';
  return 'Working late? 🌙';
}

export default function Login() {
  const [email, setEmail] = useState('admin@office.com');
  const [password, setPassword] = useState('Admin123!');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [focus, setFocus] = useState(null); // 'email' | 'password' | null
  const [mood, setMood] = useState('idle'); // idle | happy | sad | curious
  const [look, setLook] = useState({ x: 0, y: 0 });
  const [shakeKey, setShakeKey] = useState(0);
  const mascotRef = useRef(null);
  const raf = useRef(0);
  const { login } = useAuth();
  const navigate = useNavigate();

  // Eyes follow the mouse while no field is focused (rAF-throttled).
  useEffect(() => {
    const onMove = (e) => {
      if (raf.current) return;
      raf.current = requestAnimationFrame(() => {
        raf.current = 0;
        if (focus || !mascotRef.current) return;
        const r = mascotRef.current.getBoundingClientRect();
        const dx = e.clientX - (r.left + r.width / 2);
        const dy = e.clientY - (r.top + r.height / 2);
        setLook({ x: Math.max(-1, Math.min(1, dx / 300)), y: Math.max(-1, Math.min(1, dy / 240)) });
      });
    };
    window.addEventListener('mousemove', onMove, { passive: true });
    return () => {
      window.removeEventListener('mousemove', onMove);
      cancelAnimationFrame(raf.current);
      raf.current = 0;
    };
  }, [focus]);

  // While typing the email, the eyes track the text caret.
  useEffect(() => {
    if (focus === 'email') setLook({ x: -0.9 + Math.min(email.length / 28, 1) * 1.8, y: 0.9 });
  }, [focus, email]);

  const resetMood = useCallback(() => {
    if (mood === 'sad') setMood('idle');
    if (error) setError('');
  }, [mood, error]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const user = await login(email, password);
      setMood('happy');
      setFocus(null);
      // Let Tiki celebrate for a moment before leaving.
      setTimeout(() => navigate(user.role === 'SUPER_ADMIN' ? '/users' : '/attendance'), 1100);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to sign in. Please check your credentials.');
      setMood('sad');
      setShakeKey((k) => k + 1);
      setLoading(false);
    }
  };

  const state =
    mood === 'happy' ? 'success' : mood === 'sad' ? 'error' : focus === 'password' ? (showPassword ? 'peek' : 'password') : focus === 'email' ? 'email' : 'idle';
  const [line1, line2] = state === 'idle' ? [greetingLine(), LINES.idle[0]] : LINES[state];

  return (
    <div className="min-h-screen grid lg:grid-cols-[1.1fr_1fr] bg-[#F5F6FA] overflow-hidden">
      {/* ------------------------------------------------------------ */}
      {/* Brand panel with floating doodles                            */}
      {/* ------------------------------------------------------------ */}
      <div className="aurora relative hidden lg:flex flex-col justify-between p-12 text-white">
        <span className="aurora-blob" />
        <div className="absolute inset-0 dot-grid-dark pointer-events-none" />

        <div className="doodle" style={{ top: '16%', right: '14%', '--d': '7s' }}>
          <DoodleCalendar size={86} />
        </div>
        <div className="doodle" style={{ top: '44%', right: '30%', '--d': '6s', '--delay': '-2s', '--r0': '8deg', '--r1': '-4deg' }}>
          <DoodleCoffee size={76} />
        </div>
        <div className="doodle" style={{ bottom: '20%', right: '10%', '--d': '8s', '--delay': '-4s' }}>
          <DoodleMedal size={78} />
        </div>
        <div className="doodle" style={{ top: '9%', left: '46%', '--d': '9s', '--delay': '-1s', '--r0': '-14deg', '--r1': '4deg' }}>
          <DoodlePlane size={64} />
        </div>
        <div className="doodle" style={{ top: '30%', right: '6%', '--d': '4s' }}>
          <DoodleSparkle size={26} />
        </div>
        <div className="doodle" style={{ bottom: '34%', right: '40%', '--d': '5s', '--delay': '-3s' }}>
          <DoodleSparkle size={18} color="#FF8FA3" />
        </div>
        <div className="doodle" style={{ bottom: '12%', right: '34%', '--d': '6.5s', '--delay': '-1.5s' }}>
          <DoodleHeart size={26} />
        </div>

        <div className="relative flex items-center gap-3">
          <div className="p-2.5 bg-white rounded-2xl shadow-lg">
            <img src="/fujitsu.png" alt="Fujitsu" className="h-8 w-8 object-contain" />
          </div>
          <div>
            <p className="font-extrabold tracking-tight">FID Attendance</p>
            <p className="text-[10px] font-bold text-brand-400 tracking-[0.2em]">FUJITSU OFFICE</p>
          </div>
        </div>

        <div className="relative max-w-md animate-slide-up">
          <h1 className="text-5xl font-extrabold tracking-tight leading-[1.05]">
            Show up.
            <br />
            Stay consistent.
            <br />
            <span className="bg-gradient-to-r from-amber-300 via-orange-400 to-brand-400 bg-clip-text text-transparent">
              Get recognised.
            </span>
          </h1>
          <p className="text-white/60 mt-5 leading-relaxed">
            Check in with a tap, keep your weekday streak alive and collect badges for the extra mile.
          </p>
          <div className="flex gap-3 mt-7">
            {[
              ['🔥', 'Streaks'],
              ['🌙', 'Overtime'],
              ['🏅', 'Badges'],
            ].map(([e, t]) => (
              <span key={t} className="px-3.5 py-2 rounded-2xl bg-white/10 border border-white/15 text-sm font-bold backdrop-blur-sm">
                {e} {t}
              </span>
            ))}
          </div>
        </div>
        <p className="relative text-xs text-white/40">© {new Date().getFullYear()} Fujitsu Indonesia</p>
      </div>

      {/* ------------------------------------------------------------ */}
      {/* Form with the interactive mascot                             */}
      {/* ------------------------------------------------------------ */}
      <div className="relative flex items-center justify-center p-6">
        <div className="absolute -top-24 -right-24 w-72 h-72 rounded-full bg-brand-500/10 blur-3xl pointer-events-none" />
        <div className="absolute -bottom-24 -left-24 w-72 h-72 rounded-full bg-amber-400/10 blur-3xl pointer-events-none" />

        <div className="relative w-full max-w-sm">
          {/* Mascot + speech bubble */}
          <div className="flex items-end gap-2 mb-2 animate-slide-up">
            <div ref={mascotRef} className="-ml-3">
              <Mascot size={128} look={look} cover={focus === 'password' && mood !== 'sad'} peek={showPassword} mood={mood} />
            </div>
            <div key={state} className="bubble-in relative mb-16 px-4 py-3 bg-white rounded-2xl rounded-bl-md shadow-soft border border-slate-100">
              <p className="text-sm font-extrabold text-slate-900 leading-tight">{line1}</p>
              <p className="text-xs text-slate-500 mt-0.5">{line2}</p>
            </div>
          </div>

          <div
            key={shakeKey}
            className={`bg-white rounded-[28px] p-7 shadow-[0_20px_60px_-24px_rgba(15,23,42,0.25)] border border-slate-100 animate-scale-in ${shakeKey ? 'card-shake' : ''}`}
          >
            <h2 className="text-2xl font-extrabold tracking-tight text-slate-900">Welcome back</h2>
            <p className="text-sm text-slate-500 mt-1">You stay signed in unless the app is unused for 30 days.</p>

            <form onSubmit={handleSubmit} className="mt-6 space-y-4">
              {error && (
                <div className="p-3.5 bg-rose-50 border border-rose-200 text-rose-700 rounded-2xl text-xs font-semibold flex items-center gap-2.5 animate-slide-down">
                  <AlertCircle className="w-4 h-4 shrink-0" />
                  <span>{error}</span>
                </div>
              )}

              <label className="block">
                <span className="block text-xs font-bold text-slate-700 mb-2">Email address</span>
                <div className="relative group">
                  <Mail className="w-[18px] h-[18px] text-slate-400 group-focus-within:text-brand-500 transition-colors absolute left-4 top-1/2 -translate-y-1/2" />
                  <input
                    type="email"
                    required
                    autoComplete="username"
                    value={email}
                    onFocus={() => setFocus('email')}
                    onBlur={() => setFocus(null)}
                    onChange={(e) => {
                      setEmail(e.target.value);
                      resetMood();
                    }}
                    className="w-full pl-11 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-2xl text-sm text-slate-900 focus:bg-white focus:outline-none focus:ring-4 focus:ring-brand-500/15 focus:border-brand-500 transition-all"
                    placeholder="name@company.com"
                  />
                </div>
              </label>

              <label className="block">
                <span className="block text-xs font-bold text-slate-700 mb-2">Password</span>
                <div className="relative group">
                  <Lock className="w-[18px] h-[18px] text-slate-400 group-focus-within:text-brand-500 transition-colors absolute left-4 top-1/2 -translate-y-1/2" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    required
                    autoComplete="current-password"
                    value={password}
                    onFocus={() => setFocus('password')}
                    onBlur={() => setFocus(null)}
                    onChange={(e) => {
                      setPassword(e.target.value);
                      resetMood();
                    }}
                    className="w-full pl-11 pr-12 py-3 bg-slate-50 border border-slate-200 rounded-2xl text-sm text-slate-900 focus:bg-white focus:outline-none focus:ring-4 focus:ring-brand-500/15 focus:border-brand-500 transition-all"
                    placeholder="••••••••"
                  />
                  <button
                    type="button"
                    // Keep focus in the field so Tiki keeps covering / peeking.
                    onMouseDown={(e) => e.preventDefault()}
                    onClick={() => setShowPassword((v) => !v)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 p-1.5 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </label>

              <button
                type="submit"
                disabled={loading}
                className="group w-full py-3.5 bg-gradient-to-br from-brand-400 via-brand-500 to-brand-700 text-white font-extrabold rounded-2xl text-sm shadow-glow hover:brightness-110 active:scale-[0.98] transition-all disabled:opacity-70 flex items-center justify-center gap-2"
              >
                {mood === 'happy' ? (
                  'Let’s go! 🎉'
                ) : loading ? (
                  <>
                    <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    Signing in…
                  </>
                ) : (
                  <>
                    Sign in
                    <ArrowRight className="w-4 h-4 transition-transform group-hover:translate-x-1" />
                  </>
                )}
              </button>
            </form>
          </div>

          <p className="text-[11px] text-slate-400 mt-6 text-center">
            Default Super Admin: <span className="font-semibold text-slate-600">admin@office.com</span> /{' '}
            <span className="font-semibold text-slate-600">Admin123!</span>
          </p>
        </div>
      </div>

      {mood === 'happy' && (
        <div className="fixed inset-0 pointer-events-none z-50">
          <Confetti seed="login" />
        </div>
      )}
    </div>
  );
}
