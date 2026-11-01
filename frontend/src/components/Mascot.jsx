import React, { memo } from 'react';

/**
 * "Tiki" — the FID Attendance mascot: a little alarm clock with feelings.
 *
 * Props
 *  look:  { x: -1..1, y: -1..1 }  where the eyes point
 *  cover: boolean                  hands over the eyes (typing a password)
 *  peek:  boolean                  one hand lowered (password visible)
 *  mood:  'idle' | 'happy' | 'sad' | 'curious'
 *
 * Everything animates with CSS transitions/keyframes on transform/opacity,
 * so the browser can run it on the compositor without React re-rendering.
 */
function MascotImpl({ look = { x: 0, y: 0 }, cover = false, peek = false, mood = 'idle', size = 180, className = '' }) {
  const happy = mood === 'happy';
  const sad = mood === 'sad';
  const ex = Math.max(-1, Math.min(1, look.x)) * 5;
  const ey = Math.max(-1, Math.min(1, look.y)) * 3.5;

  const leftArm = cover ? -131 : happy ? 150 : 28;
  const rightArm = cover ? (peek ? 95 : 131) : happy ? -150 : -28;

  return (
    <div
      className={`relative select-none ${happy ? 'tiki-jump' : sad ? 'tiki-shake' : 'tiki-bob'} ${className}`}
      style={{ width: size, height: size * 1.05 }}
      aria-hidden
    >
      <svg viewBox="0 0 200 210" width={size} height={size * 1.05} className="overflow-visible">
        <defs>
          <radialGradient id="tiki-body" cx="0.35" cy="0.3" r="0.85">
            <stop offset="0" stopColor="#FF7A6E" />
            <stop offset="0.55" stopColor="#E11D2E" />
            <stop offset="1" stopColor="#9E0D1C" />
          </radialGradient>
          <linearGradient id="tiki-bell" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#FFE9A8" />
            <stop offset="0.5" stopColor="#FFC23D" />
            <stop offset="1" stopColor="#D98A00" />
          </linearGradient>
          <radialGradient id="tiki-face" cx="0.4" cy="0.35" r="0.8">
            <stop offset="0" stopColor="#FFFFFF" />
            <stop offset="1" stopColor="#FFF1EC" />
          </radialGradient>
        </defs>

        {/* ground shadow */}
        <ellipse cx="100" cy="198" rx="52" ry="7" fill="#0f172a" opacity="0.12" className="tiki-shadow" />

        {/* feet */}
        <g fill="#9E0D1C">
          <ellipse cx="74" cy="184" rx="13" ry="8" />
          <ellipse cx="126" cy="184" rx="13" ry="8" />
        </g>

        {/* bells + hammer */}
        <g className={happy ? 'tiki-ring' : ''} style={{ transformOrigin: '100px 70px' }}>
          <line x1="100" y1="40" x2="100" y2="54" stroke="#D98A00" strokeWidth="5" strokeLinecap="round" />
          <circle cx="100" cy="38" r="6" fill="url(#tiki-bell)" />
          <path d="M44 62 A26 26 0 0 1 82 30 Z" fill="url(#tiki-bell)" stroke="#C47A00" strokeWidth="2" />
          <path d="M156 62 A26 26 0 0 0 118 30 Z" fill="url(#tiki-bell)" stroke="#C47A00" strokeWidth="2" />
        </g>

        {/* body */}
        <circle cx="100" cy="112" r="66" fill="url(#tiki-body)" />
        <ellipse cx="78" cy="70" rx="18" ry="9" fill="white" opacity="0.28" transform="rotate(-28 78 70)" />
        <circle cx="100" cy="112" r="51" fill="url(#tiki-face)" />

        {/* clock ticks */}
        {Array.from({ length: 12 }).map((_, i) => {
          const a = (i * Math.PI) / 6;
          const r1 = 45;
          const r2 = i % 3 === 0 ? 39 : 42;
          return (
            <line
              key={i}
              x1={100 + r1 * Math.sin(a)}
              y1={112 - r1 * Math.cos(a)}
              x2={100 + r2 * Math.sin(a)}
              y2={112 - r2 * Math.cos(a)}
              stroke="#F3B6B0"
              strokeWidth={i % 3 === 0 ? 3 : 2}
              strokeLinecap="round"
            />
          );
        })}

        {/* eyes */}
        <g style={{ transform: `translate(${ex}px, ${ey}px)`, transition: 'transform 220ms cubic-bezier(0.2,0,0,1)' }}>
          {happy ? (
            <g fill="none" stroke="#1F1A24" strokeWidth="5" strokeLinecap="round">
              <path d="M70 106 Q80 94 90 106" />
              <path d="M110 106 Q120 94 130 106" />
            </g>
          ) : (
            <g className="tiki-blink">
              <ellipse cx="80" cy="104" rx="8.5" ry={sad ? 9 : 11} fill="#1F1A24" />
              <ellipse cx="120" cy="104" rx="8.5" ry={sad ? 9 : 11} fill="#1F1A24" />
              <circle cx="83" cy="99" r="3.2" fill="white" />
              <circle cx="123" cy="99" r="3.2" fill="white" />
              <circle cx="77" cy="108" r="1.5" fill="white" opacity="0.8" />
              <circle cx="117" cy="108" r="1.5" fill="white" opacity="0.8" />
            </g>
          )}
          {sad && (
            <g stroke="#1F1A24" strokeWidth="3.5" strokeLinecap="round">
              <line x1="70" y1="88" x2="88" y2="92" />
              <line x1="130" y1="88" x2="112" y2="92" />
            </g>
          )}
          {mood === 'curious' && !happy && (
            <path d="M110 86 Q120 80 130 86" fill="none" stroke="#1F1A24" strokeWidth="3.5" strokeLinecap="round" />
          )}
        </g>

        {/* cheeks */}
        <ellipse cx="68" cy="124" rx="9" ry="5.5" fill="#FF8FA3" opacity={happy ? 0.85 : 0.55} />
        <ellipse cx="132" cy="124" rx="9" ry="5.5" fill="#FF8FA3" opacity={happy ? 0.85 : 0.55} />

        {/* mouth */}
        {happy ? (
          <g>
            <path d="M86 126 Q100 146 114 126 Z" fill="#7A1020" />
            <path d="M93 136 Q100 132 107 136 Q100 142 93 136 Z" fill="#FF6B81" />
          </g>
        ) : sad ? (
          <path d="M88 138 Q100 128 112 138" fill="none" stroke="#1F1A24" strokeWidth="4" strokeLinecap="round" />
        ) : cover ? (
          <ellipse cx="100" cy="132" rx="5" ry="6" fill="#7A1020" />
        ) : (
          <path d="M88 128 Q100 140 112 128" fill="none" stroke="#1F1A24" strokeWidth="4" strokeLinecap="round" />
        )}

        {/* arms (rotate around the shoulder) */}
        <g transform="translate(46 132)">
          <g style={{ transform: `rotate(${leftArm}deg)`, transition: 'transform 380ms cubic-bezier(0.34,1.56,0.64,1)' }}>
            <line x1="0" y1="0" x2="0" y2="40" stroke="#B3121F" strokeWidth="9" strokeLinecap="round" />
            <circle cx="0" cy="44" r="11" fill="white" stroke="#B3121F" strokeWidth="3" />
          </g>
        </g>
        <g transform="translate(154 132)">
          <g style={{ transform: `rotate(${rightArm}deg)`, transition: 'transform 380ms cubic-bezier(0.34,1.56,0.64,1)' }}>
            <line x1="0" y1="0" x2="0" y2="40" stroke="#B3121F" strokeWidth="9" strokeLinecap="round" />
            <circle cx="0" cy="44" r="11" fill="white" stroke="#B3121F" strokeWidth="3" />
          </g>
        </g>
      </svg>
    </div>
  );
}

const Mascot = memo(MascotImpl);
export default Mascot;

/* ------------------------------------------------------------------------ */
/* Cute floating doodles used as decoration around the login screen.        */
/* ------------------------------------------------------------------------ */

export function DoodleCalendar({ size = 64 }) {
  return (
    <svg viewBox="0 0 64 64" width={size} height={size}>
      <rect x="6" y="12" width="52" height="46" rx="10" fill="#fff" />
      <rect x="6" y="12" width="52" height="16" rx="10" fill="#E11D2E" />
      <rect x="6" y="22" width="52" height="6" fill="#E11D2E" />
      <rect x="18" y="6" width="5" height="12" rx="2.5" fill="#1F2937" />
      <rect x="41" y="6" width="5" height="12" rx="2.5" fill="#1F2937" />
      <path d="M22 42 l7 7 l14 -14" fill="none" stroke="#10B981" strokeWidth="5" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="20" cy="35" r="1.6" fill="#1F2937" />
      <circle cx="44" cy="35" r="1.6" fill="#1F2937" />
    </svg>
  );
}

export function DoodleCoffee({ size = 60 }) {
  return (
    <svg viewBox="0 0 64 64" width={size} height={size}>
      <g className="steam" fill="none" stroke="#fff" strokeOpacity="0.8" strokeWidth="3" strokeLinecap="round">
        <path d="M24 16 q-4 -5 0 -10" />
        <path d="M34 16 q-4 -5 0 -10" />
      </g>
      <path d="M12 22 h36 v18 a14 14 0 0 1 -14 14 h-8 a14 14 0 0 1 -14 -14 z" fill="#FFB020" />
      <path d="M48 27 h4 a7 7 0 0 1 0 14 h-5" fill="none" stroke="#FFB020" strokeWidth="5" />
      <circle cx="24" cy="36" r="2.2" fill="#3B2410" />
      <circle cx="36" cy="36" r="2.2" fill="#3B2410" />
      <path d="M26 42 q4 4 8 0" fill="none" stroke="#3B2410" strokeWidth="2.4" strokeLinecap="round" />
      <ellipse cx="20" cy="41" rx="3" ry="2" fill="#FF8FA3" opacity="0.7" />
      <ellipse cx="40" cy="41" rx="3" ry="2" fill="#FF8FA3" opacity="0.7" />
    </svg>
  );
}

export function DoodleMedal({ size = 56 }) {
  return (
    <svg viewBox="0 0 64 64" width={size} height={size}>
      <path d="M20 4 h10 l6 18 h-10 z" fill="#8B5CF6" />
      <path d="M44 4 h-10 l-6 18 h10 z" fill="#FF7A1A" />
      <circle cx="32" cy="40" r="19" fill="#F5B70A" stroke="#8F5A00" strokeWidth="3" />
      <circle cx="32" cy="40" r="12" fill="#FFE27A" />
      <path d="M32 31 l3 6 l6.5 .8 l-4.8 4.5 l1.3 6.4 l-6 -3.3 l-6 3.3 l1.3 -6.4 l-4.8 -4.5 l6.5 -.8 z" fill="#E11D2E" />
    </svg>
  );
}

export function DoodlePlane({ size = 58 }) {
  return (
    <svg viewBox="0 0 64 64" width={size} height={size}>
      <path d="M4 30 L60 8 L44 56 L32 38 Z" fill="#fff" />
      <path d="M32 38 L60 8 L26 34 Z" fill="#CBD5E1" />
      <path d="M32 38 l-2 14 l8 -8" fill="#94A3B8" />
    </svg>
  );
}

export function DoodleSparkle({ size = 28, color = '#FFD34D' }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size}>
      <path d="M12 0 Q12 12 24 12 Q12 12 12 24 Q12 12 0 12 Q12 12 12 0 Z" fill={color} />
    </svg>
  );
}

export function DoodleHeart({ size = 30 }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size}>
      <path d="M12 21 C-6 9 4 -3 12 5 C20 -3 30 9 12 21 Z" fill="#FF6B81" />
    </svg>
  );
}
