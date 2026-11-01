import React, { memo, useId } from 'react';

// Vector medal artwork for achievement badges (mirrors the mobile app).
//  * STREAK   → hexagon medal with a flame emblem
//  * OVERTIME → rosette medal with a moon & stars emblem
//  * tier     → bronze / silver / gold / legendary
//  * locked   → greyscale, lock and a progress ring

export const METALS = {
  1: ['#FFD2A6', '#D4803F', '#7A3B12'],
  2: ['#FFFFFF', '#B9C3D1', '#586577'],
  3: ['#FFF4B0', '#F5B70A', '#8F5A00'],
  4: ['#FFE3F1', '#B57BFF', '#3B1F7A'],
};
export const TIER_NAMES = { 1: 'Bronze', 2: 'Silver', 3: 'Gold', 4: 'Legendary' };
export const SHORT_LABEL = { STREAK_7D: '7D', STREAK_1M: '1M', STREAK_6M: '6M', STREAK_1Y: '1Y' };
export const accentFor = (b) => (b?.category === 'STREAK' ? '#FF7A1A' : '#8B5CF6');

const C = { x: 50, y: 44 };

function hexagon(r) {
  const pts = [];
  for (let i = 0; i < 6; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 3;
    pts.push(`${(C.x + r * Math.cos(a)).toFixed(2)},${(C.y + r * Math.sin(a)).toFixed(2)}`);
  }
  return `M${pts.join('L')}Z`;
}

function rosette(r, petals = 14) {
  const pts = [];
  for (let i = 0; i < petals * 2; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / petals;
    const rr = i % 2 === 0 ? r : r * 0.9;
    pts.push(`${(C.x + rr * Math.cos(a)).toFixed(2)},${(C.y + rr * Math.sin(a)).toFixed(2)}`);
  }
  return `M${pts.join('L')}Z`;
}

const FLAME_OUTER =
  'M50 22 C53.7 28.8 62.4 33.2 62.4 41.5 C62.4 48.6 56.8 53 50 53 C43.2 53 37.6 48.6 37.6 41.5 C37.6 36.2 41.3 33.2 43.8 29.8 C44.7 34.4 46.9 36.6 49.1 37.2 C47.5 31.3 48.5 26 50 22 Z';
const FLAME_INNER = 'M50 37 C53.7 40.7 56.2 44.5 56.2 47.6 C56.2 51 53.4 53 50 53 C46.6 53 43.8 51 43.8 47.6 C43.8 43.9 47.2 40.7 50 37 Z';

function Sparkle({ x, y, r, fill }) {
  return (
    <path
      d={`M${x} ${y - r} Q${x} ${y} ${x + r} ${y} Q${x} ${y} ${x} ${y + r} Q${x} ${y} ${x - r} ${y} Q${x} ${y} ${x} ${y - r}Z`}
      fill={fill}
    />
  );
}

function BadgeMedalImpl({ badge, size = 96, animate = false, showProgress = true, className = '' }) {
  const uid = useId().replace(/:/g, '');
  if (!badge) return null;
  const streak = badge.category === 'STREAK';
  const tier = Math.min(Math.max(badge.tier || 1, 1), 4);
  const metal = METALS[tier];
  const earned = !!badge.earned;
  const accent = accentFor(badge);
  const outerR = 36;
  const faceR = outerR * 0.76;
  const body = streak ? hexagon(outerR) : rosette(outerR);
  const face = streak ? hexagon(faceR) : null;
  const label = SHORT_LABEL[badge.code] || String(badge.target ?? '');
  const ribbon = streak ? ['#FF7A1A', '#C2410C'] : ['#8B5CF6', '#5B21B6'];
  const percent = Math.max(0, Math.min(1, badge.percent || 0));
  const ringR = 43;
  const ringLen = 2 * Math.PI * ringR;
  const id = (n) => `${n}-${uid}`;

  return (
    <div
      className={`relative inline-block shrink-0 ${animate && earned ? 'medal-float' : ''} ${className}`}
      style={{ width: size, height: size }}
      title={`${badge.name}${earned ? '' : ` — ${badge.progress}/${badge.target}`}`}
    >
      <svg viewBox="0 0 100 100" width={size} height={size} style={earned ? undefined : { filter: 'grayscale(1)', opacity: 0.55 }}>
        <defs>
          {tier === 4 ? (
            <linearGradient id={id('rim')} x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stopColor="#FF5A4E" />
              <stop offset="0.2" stopColor="#FFB020" />
              <stop offset="0.4" stopColor="#34D399" />
              <stop offset="0.6" stopColor="#38BDF8" />
              <stop offset="0.8" stopColor="#8B5CF6" />
              <stop offset="1" stopColor="#D9268A" />
            </linearGradient>
          ) : (
            <linearGradient id={id('rim')} x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stopColor={metal[0]} />
              <stop offset="0.45" stopColor={metal[1]} />
              <stop offset="0.8" stopColor={metal[2]} />
              <stop offset="1" stopColor={metal[1]} />
            </linearGradient>
          )}
          <radialGradient id={id('face')} cx="0.35" cy="0.3" r="0.9">
            <stop offset="0" stopColor={streak ? '#3A1420' : '#2A1F4D'} />
            <stop offset="1" stopColor={streak ? '#1A0B14' : '#110B26'} />
          </radialGradient>
          <radialGradient id={id('glow')}>
            <stop offset="0" stopColor={accent} stopOpacity="0.45" />
            <stop offset="1" stopColor={accent} stopOpacity="0" />
          </radialGradient>
          <linearGradient id={id('flame')} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#FFD34D" />
            <stop offset="0.55" stopColor="#FF7A1A" />
            <stop offset="1" stopColor="#E11D2E" />
          </linearGradient>
          <linearGradient id={id('moon')} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#FFF7D6" />
            <stop offset="1" stopColor="#FFC94D" />
          </linearGradient>
          <linearGradient id={id('ribbon')} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor={ribbon[0]} />
            <stop offset="1" stopColor={ribbon[1]} />
          </linearGradient>
          <linearGradient id={id('plate')} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor={metal[0]} />
            <stop offset="1" stopColor={metal[1]} />
          </linearGradient>
          <mask id={id('crescent')}>
            <rect width="100" height="100" fill="white" />
            <circle cx="52.5" cy="36" r="9.5" fill="black" />
          </mask>
          <clipPath id={id('clip')}>
            <path d={body} />
          </clipPath>
        </defs>

        {/* Ribbon tails */}
        {[-1, 1].map((dir) => {
          const x0 = C.x + dir * outerR * 0.18;
          const x1 = C.x + dir * outerR * 0.72;
          const top = C.y + outerR * 0.55;
          const mid = (x0 + x1) / 2;
          return (
            <g key={dir}>
              <path
                d={`M${x0} ${top} L${x1} ${top} L${x1 + dir * 1.4} 98 L${mid + dir * 0.7} 91 L${x0 - dir * 2.9} 98 Z`}
                fill={`url(#${id('ribbon')})`}
              />
              <line x1={mid} y1={top} x2={mid} y2={90} stroke="white" strokeOpacity="0.35" strokeWidth="1.8" />
            </g>
          );
        })}

        {/* Body */}
        <path d={body} transform="translate(0 3)" fill="black" fillOpacity="0.22" />
        <path d={body} fill={`url(#${id('rim')})`} />
        <path d={body} fill="none" stroke="white" strokeOpacity="0.55" strokeWidth="1.2" />

        {/* Face */}
        {streak ? (
          <path d={face} fill={`url(#${id('face')})`} stroke={metal[2]} strokeWidth="1" />
        ) : (
          <circle cx={C.x} cy={C.y} r={faceR} fill={`url(#${id('face')})`} stroke={metal[2]} strokeWidth="1" />
        )}
        <circle cx={C.x} cy={C.y} r={faceR * 0.8} fill={`url(#${id('glow')})`} />

        {/* Emblem */}
        {streak ? (
          <g transform="translate(0 -3.3)">
            <path d={FLAME_OUTER} fill={`url(#${id('flame')})`} />
            <path d={FLAME_INNER} fill="#FFF3C4" />
          </g>
        ) : (
          <g transform="translate(0 -3.3)">
            <circle cx="47.5" cy="41" r="8.4" fill={`url(#${id('moon')})`} mask={`url(#${id('crescent')})`} />
            <Sparkle x={56.3} y={36.4} r={2.2} fill="#FFF7D6" />
            <Sparkle x={58} y={43} r={1.4} fill="#E9D5FF" />
            <Sparkle x={53} y={41.4} r={0.9} fill="#FFFFFF" />
          </g>
        )}

        {/* Label plate */}
        <g>
          <rect
            x={50 - Math.max(label.length * 3.4 + 9, 26) / 2}
            y={C.y + faceR * 0.62 - 7}
            width={Math.max(label.length * 3.4 + 9, 26)}
            height="14"
            rx="7"
            fill={`url(#${id('plate')})`}
            stroke={metal[2]}
            strokeWidth="0.8"
          />
          <text
            x="50"
            y={C.y + faceR * 0.62 + 3.4}
            textAnchor="middle"
            fontSize="9.5"
            fontWeight="900"
            fill="#1A1206"
            style={{ fontFamily: 'Plus Jakarta Sans, system-ui, sans-serif', letterSpacing: 0.5 }}
          >
            {label}
          </text>
        </g>

        {/* Tier sparkles */}
        {Array.from({ length: tier }).map((_, i) => (
          <Sparkle key={i} x={50 - ((tier - 1) * 6) / 2 + i * 6} y={C.y - outerR + 4.5} r={2.6} fill="white" />
        ))}
      </svg>

      {/* Specular shine (earned + animated only) */}
      {animate && earned && (
        <div className="absolute inset-0 overflow-hidden pointer-events-none" style={{ clipPath: 'circle(36% at 50% 44%)' }}>
          <div className="medal-shine" />
        </div>
      )}

      {/* Locked overlay */}
      {!earned && (
        <>
          {showProgress && (
            <svg viewBox="0 0 100 100" width={size} height={size} className="absolute inset-0">
              <circle cx="50" cy="44" r={ringR} fill="none" stroke="#E2E8F0" strokeWidth="3" />
              {percent > 0 && (
                <circle
                  cx="50"
                  cy="44"
                  r={ringR}
                  fill="none"
                  stroke={accent}
                  strokeWidth="3"
                  strokeLinecap="round"
                  strokeDasharray={`${ringLen * percent} ${ringLen}`}
                  transform="rotate(-90 50 44)"
                  style={{ transition: 'stroke-dasharray 1s cubic-bezier(0.2,0,0,1)' }}
                />
              )}
            </svg>
          )}
          <div
            className="absolute left-1/2 -translate-x-1/2 rounded-full bg-slate-900/80 border border-white/70 flex items-center justify-center"
            style={{ bottom: size * 0.3, width: size * 0.24, height: size * 0.24 }}
          >
            <svg viewBox="0 0 24 24" width={size * 0.13} height={size * 0.13} fill="white">
              <path d="M17 9V7A5 5 0 0 0 7 7v2a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-8a2 2 0 0 0-2-2ZM9 7a3 3 0 0 1 6 0v2H9Z" />
            </svg>
          </div>
        </>
      )}
    </div>
  );
}

const BadgeMedal = memo(BadgeMedalImpl);
export default BadgeMedal;

export function StreakFlame({ size = 28, lit = true }) {
  const uid = useId().replace(/:/g, '');
  return (
    <svg viewBox="36 20 28 34" width={size * 0.82} height={size} className={lit ? 'flame-flicker' : ''} aria-hidden>
      <defs>
        <linearGradient id={`sf-${uid}`} x1="0" y1="0" x2="0" y2="1">
          {lit ? (
            <>
              <stop offset="0" stopColor="#FFD34D" />
              <stop offset="0.55" stopColor="#FF7A1A" />
              <stop offset="1" stopColor="#E11D2E" />
            </>
          ) : (
            <>
              <stop offset="0" stopColor="#CBD5E1" />
              <stop offset="1" stopColor="#64748B" />
            </>
          )}
        </linearGradient>
      </defs>
      <path d={FLAME_OUTER} fill={`url(#sf-${uid})`} />
      <path d={FLAME_INNER} fill={lit ? '#FFF3C4' : '#F1F5F9'} />
    </svg>
  );
}

/** The user's best badge, shown right next to their name in lists. */
export function NameBadge({ top, size = 22 }) {
  if (!top?.code) return null;
  const extra = (top.count || 1) - 1;
  return (
    <span className="inline-flex items-center shrink-0 transition-transform hover:scale-125" title={`${top.name}${extra > 0 ? ` +${extra} more` : ''}`}>
      <BadgeMedal badge={{ ...top, earned: true, percent: 1 }} size={size} showProgress={false} />
    </span>
  );
}
