import React, { useEffect, useState } from 'react';
import { X, Lock, Check, Gift, Loader2, Trash2 } from 'lucide-react';
import api from '../api/client';
import AvatarFrame, { RARITY, RARITY_COLOR } from './AvatarFrame';
import { THEMES, DECOR_EMOJI } from '../themes';

/**
 * Frame collection modal.
 *  mode="self"  → the signed-in user equips one of their frames.
 *  mode="admin" → a Super Admin grants / revokes ADMIN frames for `target`.
 */
export default function FramePicker({ mode = 'self', target, avatar, name, onClose, onChanged }) {
  const [frames, setFrames] = useState([]);
  const [themes, setThemes] = useState([]);
  const [equipped, setEquipped] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState('');
  const [note, setNote] = useState('');
  const [msg, setMsg] = useState(null);

  const load = async () => {
    setLoading(true);
    try {
      const res = await api.get(mode === 'admin' ? `/admin/frames/user/${target.id}` : '/frames/me');
      setFrames(res.data.frames || []);
      setThemes(res.data.themes || []);
      setEquipped(res.data.equipped || '');
    } catch (e) {
      setMsg({ type: 'error', text: e.response?.data?.error || 'Failed to load frames' });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const equip = async (code) => {
    setBusy(code || 'none');
    try {
      await api.put('/frames/equip', { code });
      setEquipped(code);
      onChanged?.(code);
    } catch (e) {
      setMsg({ type: 'error', text: e.response?.data?.error || 'Failed to equip' });
    } finally {
      setBusy('');
    }
  };

  const grant = async (code) => {
    setBusy(code);
    try {
      await api.post('/admin/frames/grant', { user_id: target.id, frame_code: code, note });
      setMsg({ type: 'ok', text: `Frame given to ${target.name} 🎁` });
      await load();
      onChanged?.();
    } catch (e) {
      setMsg({ type: 'error', text: e.response?.data?.error || 'Failed to grant' });
    } finally {
      setBusy('');
    }
  };

  const revoke = async (code) => {
    setBusy(code);
    try {
      await api.delete(`/admin/frames/grant?user_id=${target.id}&frame_code=${code}`);
      await load();
      onChanged?.();
    } finally {
      setBusy('');
    }
  };

  const list =
    mode === 'admin'
      ? [...frames.filter((f) => f.source === 'ADMIN'), ...themes.filter((t) => t.source === 'ADMIN').map((t) => ({ ...t, isTheme: true }))]
      : frames;
  const preview = equipped;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-sm animate-fade-in" onClick={onClose}>
      <div className="relative w-full max-w-3xl max-h-[88vh] overflow-hidden bg-white rounded-[28px] shadow-2xl animate-scale-in flex flex-col" onClick={(e) => e.stopPropagation()}>
        <div className="aurora p-6 text-white flex items-center gap-5">
          <span className="aurora-blob" />
          <AvatarFrame frame={preview} src={avatar} name={name} size={72} />
          <div className="relative">
            <p className="text-xs font-extrabold tracking-[0.2em] text-white/60">{mode === 'admin' ? 'GIVE A REWARD' : 'AVATAR FRAMES'}</p>
            <h3 className="text-2xl font-extrabold tracking-tight">{mode === 'admin' ? target.name : 'Your collection'}</h3>
            <p className="text-sm text-white/60">
              {mode === 'admin' ? 'Award a special frame — they get a notification.' : 'Unlock frames with badges, or receive one from a Super Admin.'}
            </p>
          </div>
          <button onClick={onClose} className="relative ml-auto self-start p-2 rounded-xl hover:bg-white/10">
            <X className="w-5 h-5" />
          </button>
        </div>

        {mode === 'admin' && (
          <div className="px-6 pt-5">
            <input
              value={note}
              onChange={(e) => setNote(e.target.value)}
              maxLength={300}
              placeholder="Optional message, e.g. “Thanks for leading the Q4 launch!”"
              className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-2xl text-sm focus:outline-none focus:ring-4 focus:ring-brand-500/15 focus:border-brand-500"
            />
          </div>
        )}
        {msg && (
          <div className={`mx-6 mt-4 p-3 rounded-2xl text-sm font-semibold ${msg.type === 'ok' ? 'bg-emerald-50 text-emerald-700' : 'bg-rose-50 text-rose-700'}`}>
            {msg.text}
          </div>
        )}

        <div className="p-6 overflow-y-auto">
          {loading ? (
            <div className="flex justify-center py-16 text-slate-400">
              <Loader2 className="w-7 h-7 animate-spin" />
            </div>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3 stagger">
              {mode === 'self' && (
                <button
                  onClick={() => equip('')}
                  className={`p-4 rounded-3xl border-2 flex flex-col items-center gap-2 transition-all hover:-translate-y-0.5 ${
                    !equipped ? 'border-brand-500 bg-brand-50/50' : 'border-slate-100 hover:border-slate-200'
                  }`}
                >
                  <AvatarFrame frame="" src={avatar} name={name} size={56} />
                  <p className="text-sm font-bold text-slate-900 mt-2">No frame</p>
                  <p className="text-[11px] text-slate-400">Classic look</p>
                </button>
              )}
              {list.map((f) => {
                const active = equipped === f.code;
                return (
                  <div
                    key={f.code}
                    className={`relative p-4 rounded-3xl border-2 flex flex-col items-center text-center gap-1 transition-all ${
                      active ? 'border-brand-500 bg-brand-50/50' : 'border-slate-100'
                    } ${f.owned || mode === 'admin' ? 'hover:-translate-y-0.5 hover:shadow-lg' : ''}`}
                  >
                    <div className={f.owned || mode === 'admin' ? '' : 'grayscale opacity-50'}>
                      {f.isTheme ? (
                        <div className="w-[74px] h-[74px] rounded-2xl flex items-center justify-center text-3xl shadow-inner" style={{ background: `linear-gradient(135deg, ${(THEMES[f.code] || THEMES.LIGHT).aurora.join(', ')})` }}>
                          {DECOR_EMOJI[(THEMES[f.code] || THEMES.LIGHT).decor] || '🎨'}
                        </div>
                      ) : (
                        <AvatarFrame frame={f.code} src={avatar} name={name} size={56} animate={f.owned} />
                      )}
                    </div>
                    {!f.owned && mode === 'self' && (
                      <span className="absolute top-3 right-3 p-1 rounded-full bg-slate-900/80 text-white">
                        <Lock className="w-3 h-3" />
                      </span>
                    )}
                    <p className="text-sm font-bold text-slate-900 mt-1 leading-tight">{f.name}</p>
                    {f.isTheme && <p className="text-[10px] font-bold text-slate-400">APP THEME</p>}
                    <p className="text-[10px] font-extrabold tracking-wider" style={{ color: RARITY_COLOR[f.rarity] }}>
                      {RARITY[f.rarity]?.toUpperCase()}
                    </p>
                    <p className="text-[11px] text-slate-400 leading-snug">{f.owned ? f.description : f.unlock_hint}</p>
                    {f.owned && f.granted_by && <p className="text-[10px] text-slate-400">from {f.granted_by}</p>}

                    {mode === 'self' && f.owned && (
                      <button
                        disabled={!!busy}
                        onClick={() => equip(f.code)}
                        className={`mt-2 w-full py-1.5 rounded-xl text-xs font-bold transition-colors ${
                          active ? 'bg-brand-500 text-white' : 'bg-slate-900 text-white hover:bg-slate-700'
                        }`}
                      >
                        {busy === f.code ? '…' : active ? (
                          <span className="inline-flex items-center gap-1">
                            <Check className="w-3.5 h-3.5" /> Equipped
                          </span>
                        ) : (
                          'Equip'
                        )}
                      </button>
                    )}
                    {mode === 'admin' &&
                      (f.owned ? (
                        <button
                          disabled={!!busy}
                          onClick={() => revoke(f.code)}
                          className="mt-2 w-full py-1.5 rounded-xl text-xs font-bold bg-rose-50 text-rose-700 hover:bg-rose-100 inline-flex items-center justify-center gap-1"
                        >
                          <Trash2 className="w-3.5 h-3.5" /> Revoke
                        </button>
                      ) : (
                        <button
                          disabled={!!busy}
                          onClick={() => grant(f.code)}
                          className="mt-2 w-full py-1.5 rounded-xl text-xs font-bold bg-gradient-to-br from-brand-400 to-brand-700 text-white inline-flex items-center justify-center gap-1"
                        >
                          {busy === f.code ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Gift className="w-3.5 h-3.5" />} Give
                        </button>
                      ))}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
