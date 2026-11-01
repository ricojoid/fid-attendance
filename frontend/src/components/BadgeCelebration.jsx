import React, { useMemo, useState } from 'react';
import BadgeMedal, { TIER_NAMES, accentFor } from './BadgeMedal';
import AvatarFrame, { FRAME_STYLES } from './AvatarFrame';

const COLORS = ['#E11D2E', '#FFB020', '#34D399', '#38BDF8', '#8B5CF6', '#D9268A'];

export function Confetti({ seed }) {
  // Pieces are generated once per badge; pure CSS transforms afterwards.
  const pieces = useMemo(
    () =>
      Array.from({ length: 80 }, (_, i) => {
        const angle = -Math.PI / 2 + (Math.random() - 0.5) * Math.PI * 1.3;
        const dist = 220 + Math.random() * 380;
        return {
          i,
          color: COLORS[i % COLORS.length],
          dx: `${Math.cos(angle) * dist}px`,
          dy: `${Math.sin(angle) * dist + 380}px`,
          rot: `${(Math.random() - 0.5) * 1080}deg`,
          dur: `${1.8 + Math.random() * 1.2}s`,
          round: Math.random() > 0.5,
        };
      }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [seed]
  );
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden>
      {pieces.map((p) => (
        <span
          key={`${seed}-${p.i}`}
          className="confetti-piece"
          style={{
            background: p.color,
            borderRadius: p.round ? '9999px' : '2px',
            width: p.round ? 9 : 7,
            height: p.round ? 9 : 14,
            '--dx': p.dx,
            '--dy': p.dy,
            '--rot': p.rot,
            '--dur': p.dur,
          }}
        />
      ))}
    </div>
  );
}

/** Full-screen "Badge unlocked" sequence. Shows each badge in turn. */
export default function BadgeCelebration({ badges, onClose, avatar }) {
  const [index, setIndex] = useState(0);
  if (!badges?.length) return null;
  const b = badges[index];
  const accent = accentFor(b);
  const last = index === badges.length - 1;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-slate-950/80 backdrop-blur-sm animate-fade-in">
      <Confetti seed={index} />
      <div key={index} className="relative flex flex-col items-center text-center px-6 max-w-md">
        <p className="text-white/70 text-xs font-extrabold tracking-[0.3em]">
          BADGE UNLOCKED{badges.length > 1 ? `  ${index + 1}/${badges.length}` : ''}
        </p>
        <div className="relative w-72 h-72 flex items-center justify-center my-2">
          <div
            className="absolute inset-0 rounded-full rays-spin"
            style={{
              background: `radial-gradient(circle, ${accent}88 0%, transparent 62%), repeating-conic-gradient(from 0deg, rgba(255,255,255,0.09) 0deg 8deg, transparent 8deg 30deg)`,
              maskImage: 'radial-gradient(circle, black 30%, transparent 70%)',
              WebkitMaskImage: 'radial-gradient(circle, black 30%, transparent 70%)',
            }}
          />
          <div className="animate-pop-in">
            <BadgeMedal badge={b} size={190} animate showProgress={false} />
          </div>
        </div>
        <div className="animate-slide-up" style={{ animationDelay: '200ms', opacity: 0 }}>
          <span
            className="inline-block px-3 py-1 rounded-full text-[11px] font-extrabold tracking-wider border"
            style={{ color: accent, borderColor: `${accent}88`, background: `${accent}22` }}
          >
            {TIER_NAMES[b.tier]?.toUpperCase()} · {b.category}
          </span>
          <h2 className="text-white text-3xl font-extrabold tracking-tight mt-3">{b.name}</h2>
          <p className="text-white/70 text-sm mt-2 leading-relaxed">{b.description}</p>
          {FRAME_STYLES[b.reward_frame] && (
            <div className="mt-4 inline-flex items-center gap-3 pl-2 pr-4 py-2 rounded-2xl bg-white/10 border border-white/20">
              <AvatarFrame frame={b.reward_frame} src={avatar} name="★" size={34} />
              <div className="text-left">
                <p className="text-[10px] font-extrabold tracking-[0.15em] text-amber-300">REWARD UNLOCKED</p>
                <p className="text-sm font-bold text-white capitalize">{b.reward_frame.replace(/_/g, ' ').toLowerCase()} avatar frame</p>
              </div>
            </div>
          )}
        </div>
        <button
          onClick={() => (last ? onClose() : setIndex((i) => i + 1))}
          className="mt-7 px-10 py-3 rounded-2xl bg-white text-slate-900 font-extrabold text-sm shadow-xl hover:scale-[1.03] active:scale-95 transition-transform"
        >
          {last ? 'Awesome!' : 'Next badge'}
        </button>
      </div>
    </div>
  );
}
