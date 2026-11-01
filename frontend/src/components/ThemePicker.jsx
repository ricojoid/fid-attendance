import React, { useEffect, useState } from 'react';
import { X, Lock, Check, Loader2 } from 'lucide-react';
import api from '../api/client';
import { THEMES, DECOR_EMOJI } from '../themes';
import { RARITY, RARITY_COLOR } from './AvatarFrame';
import { applyTheme } from '../hooks/useTheme';

function Preview({ t }) {
  return (
    <div className="rounded-2xl overflow-hidden border border-black/5" style={{ background: t.bg }}>
      <div className="h-12 p-2 flex items-end" style={{ background: `linear-gradient(135deg, ${t.aurora[0]}, ${t.ink3}, ${t.aurora[1]})` }}>
        <div className="w-10 h-2 rounded bg-white/85" />
      </div>
      <div className="p-2 space-y-1.5">
        <div className="h-4 rounded-lg" style={{ background: `linear-gradient(90deg, ${t.primaryLight}, ${t.primary}, ${t.primaryDeep})` }} />
        {[0, 1].map((i) => (
          <div key={i} className="h-3.5 rounded-md flex items-center gap-1 px-1.5" style={{ background: t.surface, border: `1px solid ${t.line}` }}>
            <span className="w-1.5 h-1.5 rounded-full" style={{ background: t.primary }} />
            <span className="w-8 h-1 rounded opacity-40" style={{ background: t.primaryDeep }} />
          </div>
        ))}
      </div>
    </div>
  );
}

/** Appearance picker: free Light/Dark + unlockable themes. */
export default function ThemePicker({ onClose, onChanged }) {
  const [themes, setThemes] = useState([]);
  const [active, setActive] = useState('LIGHT');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    api
      .get('/themes/me')
      .then((res) => {
        setThemes(res.data.themes || []);
        setActive(res.data.active || 'LIGHT');
      })
      .catch((e) => setError(e.response?.data?.error || 'Failed to load themes'))
      .finally(() => setLoading(false));
  }, []);

  const apply = async (code) => {
    setBusy(code);
    const prev = active;
    applyTheme(code); // instant preview
    setActive(code);
    try {
      await api.put('/themes/equip', { code });
      onChanged?.(code);
    } catch (e) {
      applyTheme(prev);
      setActive(prev);
      setError(e.response?.data?.error || 'Failed to apply theme');
    } finally {
      setBusy('');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-sm animate-fade-in" onClick={onClose}>
      <div className="relative w-full max-w-4xl max-h-[88vh] overflow-hidden bg-white rounded-[28px] shadow-2xl animate-scale-in flex flex-col" onClick={(e) => e.stopPropagation()}>
        <div className="aurora p-6 text-white flex items-center gap-4">
          <span className="aurora-blob" />
          <div className="relative">
            <p className="text-xs font-extrabold tracking-[0.2em] text-white/60">APPEARANCE</p>
            <h3 className="text-2xl font-extrabold tracking-tight">App theme</h3>
            <p className="text-sm text-white/60">Light & Dark are free. Unlock the others with badges, or receive one from a Super Admin.</p>
          </div>
          <button onClick={onClose} className="relative ml-auto self-start p-2 rounded-xl hover:bg-white/10">
            <X className="w-5 h-5" />
          </button>
        </div>
        {error && <div className="mx-6 mt-4 p-3 rounded-2xl bg-rose-50 text-rose-700 text-sm font-semibold">{error}</div>}
        <div className="p-6 overflow-y-auto">
          {loading ? (
            <div className="flex justify-center py-16 text-slate-400">
              <Loader2 className="w-7 h-7 animate-spin" />
            </div>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-3 stagger">
              {themes.map((t) => {
                const pal = THEMES[t.code] || THEMES.LIGHT;
                const isActive = active === t.code;
                return (
                  <button
                    key={t.code}
                    disabled={!t.owned || !!busy}
                    onClick={() => t.owned && !isActive && apply(t.code)}
                    className={`relative text-left p-2.5 rounded-3xl border-2 transition-all ${
                      isActive ? 'border-brand-500 shadow-glow' : 'border-slate-100'
                    } ${t.owned ? 'hover:-translate-y-1 hover:shadow-xl' : 'cursor-not-allowed'}`}
                  >
                    <div className={t.owned ? '' : 'opacity-40 grayscale'}>
                      <Preview t={pal} />
                    </div>
                    {DECOR_EMOJI[pal.decor] && <span className="absolute top-3 right-4 text-base">{DECOR_EMOJI[pal.decor]}</span>}
                    {!t.owned && (
                      <span className="absolute top-[38px] left-1/2 -translate-x-1/2 p-2 rounded-full bg-slate-900/80 text-white">
                        <Lock className="w-3.5 h-3.5" />
                      </span>
                    )}
                    <div className="flex items-center gap-1 mt-2 px-1">
                      <p className="font-extrabold text-sm text-slate-900 truncate flex-1">{t.name}</p>
                      {isActive && <Check className="w-4 h-4 text-brand-600" />}
                      {busy === t.code && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
                    </div>
                    <p className="px-1 text-[10px] font-extrabold tracking-wider" style={{ color: RARITY_COLOR[t.rarity] }}>
                      {RARITY[t.rarity]?.toUpperCase()}
                    </p>
                    <p className="px-1 text-[11px] text-slate-400 leading-snug line-clamp-2">{t.owned ? t.description : t.unlock_hint}</p>
                  </button>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
