import React, { memo, useMemo } from 'react';

// Ambient decoration for decorated themes. Pure CSS animations on
// transform/opacity (compositor only); sparse and pointer-events: none.

const Petal = ({ c }) => (
  <svg width="16" height="16" viewBox="-10 -10 20 20">
    <path d="M0 -8 Q8 -3 0 8 Q-8 -3 0 -8Z" fill={c} opacity="0.8" />
  </svg>
);
const Leaf = ({ c }) => (
  <svg width="18" height="18" viewBox="-10 -10 20 20">
    <path d="M0 -9 Q7 0 0 9 Q-7 0 0 -9Z" fill={c} opacity="0.75" />
    <path d="M0 -9 L0 10" stroke="#166534" strokeOpacity="0.5" strokeWidth="1" />
  </svg>
);
const Bubble = ({ s }) => (
  <svg width={s} height={s} viewBox="-10 -10 20 20">
    <circle r="9" fill="#7DD3FC" fillOpacity="0.15" stroke="#38BDF8" strokeOpacity="0.55" strokeWidth="1.2" />
    <circle cx="-3.5" cy="-3.5" r="2" fill="#fff" fillOpacity="0.8" />
  </svg>
);
const Spark = ({ c, s }) => (
  <svg width={s} height={s} viewBox="-10 -10 20 20">
    <path d="M0 -9 Q0 0 9 0 Q0 0 0 9 Q0 0 -9 0 Q0 0 0 -9Z" fill={c} />
  </svg>
);
const Candy = ({ c, i }) =>
  i % 2 ? (
    <svg width="20" height="30" viewBox="-10 -10 20 30">
      <line x1="0" y1="8" x2="0" y2="19" stroke="#fff" strokeWidth="2" />
      <circle r="8" fill={c} opacity="0.8" />
      <path d="M-4 0 A4 4 0 1 1 4 0" fill="none" stroke="#fff" strokeWidth="2" opacity="0.8" />
    </svg>
  ) : (
    <svg width="30" height="16" viewBox="-15 -8 30 16">
      <ellipse rx="8" ry="6" fill={c} opacity="0.8" />
      <path d="M8 0 L14 -5 L14 5Z M-8 0 L-14 -5 L-14 5Z" fill={c} opacity="0.8" />
    </svg>
  );
const Cloud = () => (
  <svg width="90" height="44" viewBox="0 0 90 44">
    <g fill="#fff" fillOpacity="0.55">
      <circle cx="25" cy="26" r="16" />
      <circle cx="45" cy="18" r="18" />
      <circle cx="66" cy="27" r="14" />
      <rect x="12" y="26" width="66" height="16" rx="8" />
    </g>
  </svg>
);
const Monster = ({ c, i }) => (
  <svg width="54" height="62" viewBox="-30 -40 60 70">
    {i % 2 ? (
      <>
        <line x1="0" y1="-24" x2="4" y2="-36" stroke={c} strokeWidth="2.5" />
        <circle cx="4" cy="-37" r="3.5" fill="#FDE047" />
      </>
    ) : (
      <path d="M-15 -16 L-9 -32 L-4 -20Z M15 -16 L9 -32 L4 -20Z" fill={c} />
    )}
    <ellipse rx="24" ry="22" fill={c} opacity="0.92" />
    <circle cx="-25" cy="4" r="5" fill={c} />
    <circle cx="25" cy="4" r="5" fill={c} />
    {i % 3 === 2 ? (
      <g className="monster-eye">
        <circle cy="-4" r="10" fill="#fff" />
        <circle cx="2" cy="-3" r="5" fill="#1F1A24" />
        <circle cx="4" cy="-6" r="1.6" fill="#fff" />
      </g>
    ) : (
      <g className="monster-eye">
        <circle cx="-8" cy="-4" r="6.5" fill="#fff" />
        <circle cx="8" cy="-4" r="6.5" fill="#fff" />
        <circle cx="-7" cy="-3" r="3.2" fill="#1F1A24" />
        <circle cx="9" cy="-3" r="3.2" fill="#1F1A24" />
      </g>
    )}
    <path d="M-8 8 Q0 15 8 8" fill="none" stroke="#1F1A24" strokeWidth="2.2" strokeLinecap="round" />
    <path d="M2 10 L4 15 L6 9.5Z" fill="#fff" />
  </svg>
);

function seeded(n, salt) {
  // Deterministic pseudo-random so the layout doesn't jump between renders.
  let x = (n + 1) * 9301 + salt * 49297;
  return () => {
    x = (x * 9301 + 49297) % 233280;
    return x / 233280;
  };
}

function ThemeDecorImpl({ decor }) {
  const items = useMemo(() => {
    if (!decor || decor === 'none') return [];
    const count = { monsters: 4, clouds: 4, stars: 28, goldDust: 24 }[decor] || 12;
    return Array.from({ length: count }, (_, i) => {
      const r = seeded(i, decor.length);
      return { i, left: r() * 100, top: r() * 100, dur: 10 + r() * 14, delay: -r() * 24, sway: (r() - 0.5) * 120, rot: (r() - 0.5) * 900, size: 0.7 + r() * 0.7 };
    });
  }, [decor]);
  if (!items.length) return null;

  const palette = {
    petals: ['#F9A8D4', '#FBCFE8', '#F472B6', '#FDE2EE'],
    leaves: ['#4ADE80', '#22C55E', '#84CC16', '#FACC15'],
    candy: ['#F472B6', '#60A5FA', '#FDE047', '#A78BFA'],
    monsters: ['#8B5CF6', '#22C55E', '#F59E0B', '#38BDF8'],
  }[decor] || [];

  return (
    <div className="decor-layer" aria-hidden>
      {items.map((it) => {
        const c = palette[it.i % (palette.length || 1)];
        const base = { left: `${it.left}%`, '--dur': `${it.dur}s`, '--delay': `${it.delay}s`, '--sway': `${it.sway}px`, '--rot': `${it.rot}deg` };
        switch (decor) {
          case 'petals':
          case 'leaves':
          case 'candy':
            return (
              <div key={it.i} className="decor-item decor-fall" style={{ ...base, transform: `scale(${it.size})` }}>
                {decor === 'petals' ? <Petal c={c} /> : decor === 'leaves' ? <Leaf c={c} /> : <Candy c={c} i={it.i} />}
              </div>
            );
          case 'bubbles':
            return (
              <div key={it.i} className="decor-item decor-rise" style={base}>
                <Bubble s={12 + it.size * 12} />
              </div>
            );
          case 'stars':
          case 'goldDust':
            return (
              <div key={it.i} className="decor-item decor-twinkle" style={{ ...base, top: `${it.top}%`, '--dur': `${2 + it.size * 2}s` }}>
                <Spark c={decor === 'stars' ? '#fff' : '#FCD34D'} s={6 + it.size * 6} />
              </div>
            );
          case 'clouds':
          case 'monsters':
            return (
              <div key={it.i} className="decor-item decor-drift" style={{ ...base, top: `${8 + it.top * 0.8}%`, '--dur': `${35 + it.dur * 2}s` }}>
                <div>{decor === 'clouds' ? <Cloud /> : <Monster c={c} i={it.i} />}</div>
              </div>
            );
          default:
            return null;
        }
      })}
    </div>
  );
}

const ThemeDecor = memo(ThemeDecorImpl);
export default ThemeDecor;
