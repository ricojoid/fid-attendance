import React, { memo, useId } from 'react';
import { isImageSrc } from '../utils/image';

// Visual + motion spec for every avatar frame (mirrors the mobile app).
//   colors   → conic ring gradient ('brand' = follows the active theme)
//   spin     → ring rotation period in seconds (0 = still)
//   ornament → decoration on top of the ring
//   orbit    → particles circling the avatar: [kind, count, seconds]
//   fx       → extra effects: pulse, rays, hue, zap
export const FRAME_STYLES = {
  // Free starters
  GLOW: { colors: 'brand', spin: 0, glow: 'brand', fx: ['pulse'] },
  BUBBLES: { colors: ['#E0F2FE', '#38BDF8', '#0EA5E9', '#7DD3FC', '#E0F2FE'], spin: 14, glow: '#38BDF8', orbit: ['bubble', 6, 9], fx: ['pulse'] },
  SUNNY: { colors: ['#FEF08A', '#FACC15', '#F97316', '#FACC15', '#FEF08A'], spin: 10, glow: '#FACC15', fx: ['rays', 'pulse'] },
  // Achievements
  EMBER: { colors: ['#FFD34D', '#FF7A1A', '#E11D2E', '#FF7A1A', '#FFD34D'], spin: 12, ornament: 'flame', glow: '#FF7A1A', orbit: ['ember', 3, 7], fx: ['pulse'] },
  BLAZE: { colors: ['#FFE08A', '#FF7A1A', '#E11D2E', '#7A0010', '#E11D2E', '#FF7A1A', '#FFE08A'], spin: 4, ornament: 'flames', glow: '#FF5A1A', orbit: ['ember', 6, 4], fx: ['pulse'] },
  INFERNO_CROWN: { colors: ['#FFF1A8', '#F5B70A', '#FF7A1A', '#E11D2E', '#F5B70A', '#FFF1A8'], spin: 6, ornament: 'crown', glow: '#F5B70A', orbit: ['ember', 5, 5], fx: ['pulse'] },
  PHOENIX: { colors: ['#FF5A4E', '#FFB020', '#FFE08A', '#FF7A1A', '#D9268A', '#FF5A4E'], spin: 4, ornament: 'wings', glow: '#FF7A1A', orbit: ['spark', 8, 5], fx: ['pulse', 'hue'] },
  MOONLIGHT: { colors: ['#F8FAFC', '#93C5FD', '#64748B', '#93C5FD', '#F8FAFC'], spin: 18, ornament: 'moon', glow: '#93C5FD', orbit: ['spark', 3, 10], fx: ['pulse'] },
  NIGHT_OWL: { colors: ['#C4B5FD', '#7C3AED', '#1E1B4B', '#7C3AED', '#C4B5FD'], spin: 14, ornament: 'stars', glow: '#7C3AED', orbit: ['star', 4, 9], fx: ['pulse'] },
  GALAXY: { colors: ['#38BDF8', '#8B5CF6', '#D946EF', '#1E1B4B', '#38BDF8'], spin: 5, ornament: 'stars', glow: '#8B5CF6', orbit: ['spark', 7, 6], fx: ['pulse'] },
  ECLIPSE: { colors: ['#111827', '#FDE68A', '#111827', '#F59E0B', '#111827'], spin: 5, ornament: 'corona', glow: '#F59E0B', orbit: ['spark', 4, 7], fx: ['pulse'] },
  // Admin gifts
  EMPLOYEE_OF_MONTH: { colors: ['#FFF4B0', '#F5B70A', '#8F5A00', '#F5B70A', '#FFF4B0'], spin: 10, ornament: 'laurel', glow: '#F5B70A', orbit: ['spark', 4, 8], fx: ['pulse'] },
  RISING_STAR: { colors: ['#FFD1E8', '#FF6BB5', '#FFD34D', '#FF6BB5', '#FFD1E8'], spin: 9, ornament: 'star', glow: '#FF6BB5', orbit: ['star', 5, 7], fx: ['pulse'] },
  TEAM_HERO: { colors: ['#BFDBFE', '#2563EB', '#1E3A8A', '#2563EB', '#BFDBFE'], spin: 10, ornament: 'shield', glow: '#2563EB', orbit: ['spark', 3, 8], fx: ['pulse'] },
  BIRTHDAY: { colors: ['#F43F5E', '#F59E0B', '#22C55E', '#3B82F6', '#A855F7', '#F43F5E'], spin: 5, ornament: 'hat', glow: '#F59E0B', orbit: ['confetti', 8, 6], fx: ['pulse'] },
  FOUNDERS_CIRCLE: { colors: ['#FFE08A', '#E11D2E', '#7A0010', '#F5B70A', '#E11D2E', '#FFE08A'], spin: 5, ornament: 'crown', glow: '#E11D2E', orbit: ['gem', 6, 7], fx: ['pulse'] },
  CHERRY_BLOSSOM: { colors: ['#FFE4EF', '#F9A8D4', '#EC4899', '#F9A8D4', '#FFE4EF'], spin: 12, glow: '#F472B6', orbit: ['petal', 7, 8], fx: ['pulse'] },
  NEON_PULSE: { colors: ['#22D3EE', '#A855F7', '#F0ABFC', '#22D3EE'], spin: 3, glow: '#22D3EE', fx: ['pulse', 'neon', 'hue'] },
  SNOWFALL: { colors: ['#F0F9FF', '#BAE6FD', '#7DD3FC', '#BAE6FD', '#F0F9FF'], spin: 16, glow: '#7DD3FC', orbit: ['snow', 7, 11], fx: ['pulse'] },
  LIGHTNING: { colors: ['#FDE047', '#38BDF8', '#1E3A8A', '#38BDF8', '#FDE047'], spin: 3, glow: '#38BDF8', fx: ['pulse', 'zap'] },
  HEARTBEAT: { colors: ['#FECDD3', '#F43F5E', '#BE123C', '#F43F5E', '#FECDD3'], spin: 10, ornament: 'heart', glow: '#F43F5E', orbit: ['heart', 4, 7], fx: ['pulse'] },
  DIAMOND: { colors: ['#22D3EE', '#FFFFFF', '#A78BFA', '#F472B6', '#FFFFFF', '#FACC15', '#22D3EE'], spin: 4, ornament: 'gem', glow: '#A5F3FC', orbit: ['spark', 8, 5], fx: ['pulse', 'hue'] },
};

export const RARITY = { 1: 'Common', 2: 'Rare', 3: 'Epic', 4: 'Legendary' };
export const RARITY_COLOR = { 1: '#64748B', 2: '#2563EB', 3: '#9333EA', 4: '#F59E0B' };

const BRAND_RING = ['rgb(var(--brand-300))', 'rgb(var(--brand-600))', 'rgb(var(--brand-800))', 'rgb(var(--brand-600))', 'rgb(var(--brand-300))'];

function Sparkle({ x, y, r, c, className }) {
  return <path className={className} d={`M${x} ${y - r} Q${x} ${y} ${x + r} ${y} Q${x} ${y} ${x} ${y + r} Q${x} ${y} ${x - r} ${y} Q${x} ${y} ${x} ${y - r}Z`} fill={c} />;
}

function Particle({ kind, i }) {
  switch (kind) {
    case 'petal':
      return <path d="M0 -5 Q5 -2 0 5 Q-5 -2 0 -5Z" fill={['#F9A8D4', '#FBCFE8', '#F472B6'][i % 3]} />;
    case 'heart':
      return <path d="M0 4 C-7 -1 -3 -6 0 -3 C3 -6 7 -1 0 4Z" fill="#F43F5E" />;
    case 'snow':
      return (
        <g stroke="#fff" strokeWidth="1.3" strokeLinecap="round">
          <path d="M0 -4.5 V4.5 M-3.9 -2.2 L3.9 2.2 M-3.9 2.2 L3.9 -2.2" />
        </g>
      );
    case 'bubble':
      return (
        <g>
          <circle r={2.5 + (i % 3)} fill="#7DD3FC" fillOpacity="0.25" stroke="#38BDF8" strokeWidth="0.9" />
          <circle cx="-1" cy="-1" r="0.8" fill="#fff" />
        </g>
      );
    case 'ember':
      return <circle r={1.6 + (i % 2)} fill={['#FFD34D', '#FF7A1A', '#FFE08A'][i % 3]} />;
    case 'star':
      return <Sparkle x={0} y={0} r={3.4} c={['#FFD34D', '#fff', '#E9D5FF'][i % 3]} />;
    case 'confetti':
      return <rect x="-1.4" y="-2.4" width="2.8" height="4.8" rx="0.8" fill={['#F43F5E', '#F59E0B', '#22C55E', '#3B82F6', '#A855F7'][i % 5]} />;
    case 'gem':
      return <path d="M0 -3.6 L3 0 L0 3.6 L-3 0Z" fill={['#38BDF8', '#F43F5E', '#22C55E'][i % 3]} stroke="#fff" strokeWidth="0.6" />;
    default:
      return <Sparkle x={0} y={0} r={2.8} c="#fff" />;
  }
}

function Ornament({ kind, uid }) {
  switch (kind) {
    case 'crown':
      return (
        <g className="orn-bob">
          <g transform="translate(50 6)">
            <path d="M-14 6 L-10 -8 L-4 1 L0 -11 L4 1 L10 -8 L14 6 Z" fill={`url(#gold-${uid})`} stroke="#8F5A00" strokeWidth="1.2" strokeLinejoin="round" />
            <circle cx="0" cy="-11" r="2" fill="#E11D2E" className="orn-twinkle" />
            <circle cx="-10" cy="-8" r="1.6" fill="#38BDF8" />
            <circle cx="10" cy="-8" r="1.6" fill="#38BDF8" />
          </g>
        </g>
      );
    case 'moon':
      return (
        <g className="orn-bob">
          <g transform="translate(84 16)">
            <circle r="9" fill="#F8FAFC" />
            <circle cx="4" cy="-3" r="8" fill="#93C5FD" />
          </g>
          <Sparkle x={72} y={6} r={2.4} c="#fff" className="orn-twinkle" />
        </g>
      );
    case 'star':
      return (
        <g>
          <g className="orn-bob">
            <path transform="translate(84 15)" d="M0 -10 L3 -3 L10 -3 L4.5 1.5 L6.5 9 L0 4.5 L-6.5 9 L-4.5 1.5 L-10 -3 L-3 -3 Z" fill="#FFD34D" stroke="#fff" strokeWidth="1.2" />
          </g>
          <Sparkle x={14} y={20} r={4} c="#FF6BB5" className="orn-twinkle" />
        </g>
      );
    case 'stars':
      return (
        <g>
          <Sparkle x={84} y={14} r={6} c="#fff" className="orn-twinkle" />
          <Sparkle x={12} y={24} r={4} c="#E9D5FF" className="orn-twinkle d2" />
          <Sparkle x={90} y={70} r={3.5} c="#C4B5FD" className="orn-twinkle d3" />
          <Sparkle x={20} y={86} r={3} c="#fff" className="orn-twinkle d2" />
        </g>
      );
    case 'laurel':
      return (
        <g>
          <g fill="#2E9D5A" stroke="#14532D" strokeWidth="0.6">
            {[-1, 1].map((d) =>
              [0, 1, 2, 3, 4].map((i) => {
                const a = (Math.PI / 180) * (110 + i * 16);
                const x = 50 - d * 46 * Math.cos(a);
                const y = 50 + 46 * Math.sin(a);
                return <ellipse key={`${d}${i}`} cx={x} cy={y} rx="3.4" ry="7" transform={`rotate(${d * (20 + i * 16)} ${x} ${y})`} />;
              })
            )}
          </g>
          <g className="orn-bob">
            <path transform="translate(50 6)" d="M0 -7 L2 -2 L7 -2 L3 1 L4.5 6 L0 3 L-4.5 6 L-3 1 L-7 -2 L-2 -2 Z" fill="#FFD34D" stroke="#8F5A00" className="orn-twinkle" />
          </g>
        </g>
      );
    case 'shield':
      return (
        <g className="orn-bob">
          <g transform="translate(50 92)">
            <path d="M0 -10 L10 -6 L8 4 Q0 12 0 12 Q0 12 -8 4 L-10 -6 Z" fill="#2563EB" stroke="#fff" strokeWidth="1.6" />
            <path d="M0 -5 L2 -1 L6 -1 L3 2 L4 6 L0 3.5 L-4 6 L-3 2 L-6 -1 L-2 -1 Z" fill="#FFD34D" />
          </g>
        </g>
      );
    case 'hat':
      return (
        <g className="orn-wiggle" style={{ transformOrigin: '74px 20px' }}>
          <g transform="translate(74 10) rotate(25)">
            <path d="M-9 10 L0 -12 L9 10 Z" fill="#A855F7" stroke="#fff" strokeWidth="1.2" />
            <path d="M-5 0 L5 0 M-7 5 L7 5" stroke="#FDE047" strokeWidth="2" />
            <circle cy="-13" r="3" fill="#F43F5E" />
          </g>
        </g>
      );
    case 'wings':
      return (
        <g fill={`url(#gold-${uid})`} stroke="#B45309" strokeWidth="0.8">
          {[-1, 1].map((d) => (
            <g key={d} className="orn-flap" style={{ transformOrigin: `${50 + d * 44}px 46px` }}>
              <path
                transform={`translate(${50 + d * 44} 46) scale(${d} 1)`}
                d="M0 0 C8 -14 20 -16 24 -10 C18 -10 14 -6 12 -2 C18 -5 22 -3 22 1 C16 0 12 2 10 5 C14 5 16 8 14 10 C8 8 3 6 0 4 Z"
              />
            </g>
          ))}
        </g>
      );
    case 'flame':
    case 'flames':
      return (
        <g>
          {(kind === 'flame' ? [0] : [-38, 0, 38]).map((deg, i) => (
            <g key={deg} transform={`rotate(${deg} 50 50)`}>
              <g className={`orn-flicker ${i === 1 ? 'd2' : i === 2 ? 'd3' : ''}`} style={{ transformOrigin: '50px 13px' }}>
                <path
                  transform="translate(50 4)"
                  d="M0 -8 C3 -3 6 -1 6 3 C6 7 3 9 0 9 C-3 9 -6 7 -6 3 C-6 0 -3 -2 -2 -5 C-1 -2 0 -1 1 -1 C0 -3 -1 -6 0 -8 Z"
                  fill={`url(#fire-${uid})`}
                />
              </g>
            </g>
          ))}
        </g>
      );
    case 'corona':
      return (
        <g className="orn-spin-rev" style={{ transformOrigin: '50px 50px' }}>
          <g stroke="#FDE68A" strokeWidth="1.6" strokeLinecap="round" opacity="0.9">
            {Array.from({ length: 16 }).map((_, i) => {
              const a = (i * Math.PI * 2) / 16;
              const r2 = i % 2 ? 49 : 51;
              return <line key={i} x1={50 + 46 * Math.cos(a)} y1={50 + 46 * Math.sin(a)} x2={50 + r2 * Math.cos(a)} y2={50 + r2 * Math.sin(a)} />;
            })}
          </g>
        </g>
      );
    case 'heart':
      return (
        <g className="orn-beat" style={{ transformOrigin: '84px 15px' }}>
          <path transform="translate(84 15) scale(1.4)" d="M0 5 C-9 -1 -4 -8 0 -4 C4 -8 9 -1 0 5Z" fill="#F43F5E" stroke="#fff" strokeWidth="0.8" />
        </g>
      );
    case 'gem':
      return (
        <g className="orn-bob">
          <g transform="translate(50 5)">
            <path d="M-8 -2 L-4 -7 L4 -7 L8 -2 L0 8 Z" fill="#A5F3FC" stroke="#fff" strokeWidth="1" />
            <path d="M-8 -2 L8 -2 M-4 -7 L0 8 L4 -7" stroke="#fff" strokeOpacity="0.7" strokeWidth="0.6" fill="none" />
          </g>
          <Sparkle x={60} y={0} r={2.4} c="#fff" className="orn-twinkle" />
        </g>
      );
    default:
      return null;
  }
}

/**
 * Avatar with an optional reward frame.
 *  size    → diameter of the photo; the frame extends ~16% outside it.
 *  animate → run the frame's motion continuously. When false (long lists,
 *            tables) it rests and comes alive on hover of the avatar or of
 *            any `.group` row that contains it.
 */
function AvatarFrameImpl({ frame, src, name = '', size = 40, animate = true, rounded = 'full', className = '' }) {
  const uid = useId().replace(/:/g, '');
  const style = FRAME_STYLES[frame];
  const pad = style ? Math.round(size * 0.16) : 0;
  const outer = size + pad * 2;
  const ring = Math.max(2.5, size * 0.07);

  const photo = isImageSrc(src) ? (
    <img src={src} alt="" loading="lazy" decoding="async" className="w-full h-full object-cover" />
  ) : (
    <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-brand-400 to-brand-700 text-white font-extrabold" style={{ fontSize: size * 0.4 }}>
      {(name || '?').charAt(0).toUpperCase()}
    </div>
  );

  if (!style) {
    return (
      <div className={`shrink-0 overflow-hidden ${rounded === 'full' ? 'rounded-full' : 'rounded-xl'} ${className}`} style={{ width: size, height: size }}>
        {photo}
      </div>
    );
  }

  const fx = style.fx || [];
  const colors = style.colors === 'brand' ? BRAND_RING : style.colors;
  const glow = style.glow === 'brand' ? 'rgb(var(--brand-500))' : style.glow;
  const conic = `conic-gradient(from 0deg, ${colors.join(', ')})`;
  const mask = `radial-gradient(farthest-side, transparent calc(100% - ${ring}px), #000 calc(100% - ${ring}px))`;
  const [orbitKind, orbitCount, orbitSecs] = style.orbit || [];

  return (
    <div
      className={`relative shrink-0 frame-live ${animate ? '' : 'frame-paused'} ${className}`}
      style={{ width: outer, height: outer }}
      title={frame?.replace(/_/g, ' ')}
    >
      {/* breathing glow */}
      <div
        className={`absolute rounded-full ${fx.includes('pulse') ? 'frame-pulse' : ''}`}
        style={{ inset: pad * 0.55, boxShadow: `0 0 ${size * (fx.includes('neon') ? 0.45 : 0.28)}px ${glow}` , opacity: 0.55 }}
      />
      {/* sun rays */}
      {fx.includes('rays') && (
        <div
          className="absolute rounded-full frame-spin"
          style={{
            inset: -pad * 0.2,
            '--spin': '16s',
            background: 'repeating-conic-gradient(from 0deg, #FDE047 0deg 7deg, transparent 7deg 22.5deg)',
            WebkitMask: `radial-gradient(circle, transparent ${size / 2 + ring}px, #000 ${size / 2 + ring + 1}px)`,
            mask: `radial-gradient(circle, transparent ${size / 2 + ring}px, #000 ${size / 2 + ring + 1}px)`,
            opacity: 0.75,
          }}
        />
      )}
      {/* ring */}
      <div
        className={`absolute rounded-full ${style.spin ? 'frame-spin' : ''} ${fx.includes('hue') ? 'frame-hue' : ''}`}
        style={{ inset: pad - ring, background: conic, WebkitMask: mask, mask, '--spin': `${style.spin || 8}s` }}
      />
      <div className="absolute rounded-full overflow-hidden bg-white" style={{ inset: pad, boxShadow: 'inset 0 0 0 1.5px rgba(255,255,255,0.7)' }}>
        {photo}
      </div>
      <svg viewBox="0 0 100 100" className="absolute inset-0 w-full h-full overflow-visible pointer-events-none">
        <defs>
          <linearGradient id={`gold-${uid}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#FFF4B0" />
            <stop offset="1" stopColor="#F5B70A" />
          </linearGradient>
          <linearGradient id={`fire-${uid}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#FFD34D" />
            <stop offset="1" stopColor="#E11D2E" />
          </linearGradient>
        </defs>
        {/* orbiting particles */}
        {orbitKind && (
          <g className="frame-orbit" style={{ transformOrigin: '50px 50px', '--orbit': `${orbitSecs}s` }}>
            {Array.from({ length: orbitCount }).map((_, i) => {
              const a = (i / orbitCount) * Math.PI * 2;
              const r = 47 + (i % 2) * 3;
              return (
                <g key={i} transform={`translate(${50 + r * Math.cos(a)} ${50 + r * Math.sin(a)})`}>
                  <g className={`orn-twinkle ${i % 3 === 1 ? 'd2' : i % 3 === 2 ? 'd3' : ''}`}>
                    <Particle kind={orbitKind} i={i} />
                  </g>
                </g>
              );
            })}
          </g>
        )}
        {fx.includes('zap') && (
          <g fill="#FDE047" stroke="#fff" strokeWidth="0.6">
            {[
              [18, 14, -20],
              [86, 30, 15],
              [24, 86, 200],
              [82, 84, 160],
            ].map(([x, y, r], i) => (
              <path
                key={i}
                className={`orn-zap ${i % 2 ? 'd2' : ''}`}
                transform={`translate(${x} ${y}) rotate(${r})`}
                d="M-1 -8 L4 -8 L1 -1 L5 -1 L-3 9 L-1 2 L-5 2 Z"
              />
            ))}
          </g>
        )}
        <Ornament kind={style.ornament} uid={uid} />
      </svg>
    </div>
  );
}

const AvatarFrame = memo(AvatarFrameImpl);
export default AvatarFrame;
