import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { MapContainer, TileLayer, Marker, Popup, Polyline, Circle, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { CalendarDays, Users, User, MapPin, LogIn, LogOut, Crosshair, ChevronLeft, ChevronRight, Loader2 } from 'lucide-react';
import api from '../api/client';
import { NameBadge } from '../components/BadgeMedal';

const JAKARTA = [-6.2088, 106.8456];
const todayStr = () => new Date().toLocaleDateString('en-CA');
const monthStr = () => todayStr().slice(0, 7);
const fmtTime = (t) => (t ? new Date(t).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' }) : '--:--');
const fmtDate = (d) => new Date(d).toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short' });
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const PALETTE = ['#E11D2E', '#2563EB', '#059669', '#D97706', '#7C3AED', '#DB2777', '#0891B2', '#65A30D', '#EA580C', '#4F46E5'];
const colorFor = (id) => PALETTE[(Number(id) || 0) % PALETTE.length];

// Cached DivIcons: one per (label, color, kind) so markers don't rebuild DOM on every render.
const iconCache = new Map();
function pinIcon(label, color, kind, active) {
  const key = `${label}|${color}|${kind}|${active}`;
  if (iconCache.has(key)) return iconCache.get(key);
  const out = kind === 'out';
  const size = active ? 46 : 38;
  const html = `
    <div class="fid-pin ${active ? 'fid-pin-active' : ''}" style="--c:${color};width:${size}px;height:${size + 10}px">
      <div class="fid-pin-head" style="${out ? `background:#fff;color:${color};border:3px solid ${color}` : `background:${color};color:#fff;border:3px solid #fff`}">
        ${esc(label)}
      </div>
      <div class="fid-pin-tip" style="border-top-color:${out ? color : color}"></div>
      ${active ? '<span class="fid-pin-pulse"></span>' : ''}
    </div>`;
  const icon = L.divIcon({ html, className: '', iconSize: [size, size + 10], iconAnchor: [size / 2, size + 8], popupAnchor: [0, -size] });
  iconCache.set(key, icon);
  return icon;
}

const initials = (name) =>
  (name || '?')
    .split(/\s+/)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join('');

function FitBounds({ points, focus, tick }) {
  const map = useMap();
  const fitted = useRef('');
  useEffect(() => {
    if (focus) {
      map.flyTo([focus.lat, focus.long], Math.max(map.getZoom(), 16), { duration: 0.8 });
      return;
    }
    const coords = points.flatMap((p) => [p.check_in, p.check_out].filter(Boolean).map((s) => [s.lat, s.long]));
    const key = `${tick}#` + coords.map((c) => c.join(',')).join('|');
    if (!coords.length || key === fitted.current) return;
    fitted.current = key;
    if (coords.length === 1) map.setView(coords[0], 16);
    else map.fitBounds(coords, { padding: [60, 60], maxZoom: 16 });
  }, [points, focus, tick, map]);
  return null;
}

function StopPopup({ p, stop, kind }) {
  return (
    <div className="min-w-[220px]">
      <div className="flex items-center gap-1.5 font-extrabold text-slate-900 text-sm">
        {p.name} <NameBadge top={p.top_badge} size={18} />
      </div>
      <div className="text-[11px] text-slate-500">{p.department} · {fmtDate(p.date)}</div>
      <div
        className={`mt-2 inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold ${
          kind === 'in' ? 'bg-emerald-50 text-emerald-700' : 'bg-violet-50 text-violet-700'
        }`}
      >
        {kind === 'in' ? 'Check-in' : 'Check-out'} · {fmtTime(stop.time)}
        {kind === 'in' && p.status === 'LATE' ? ' · Late' : ''}
      </div>
      <div className="mt-2 text-xs text-slate-700 leading-snug">{stop.address || 'Address not available'}</div>
      <div className="mt-1 text-[11px] text-slate-400 font-mono">
        {stop.lat.toFixed(6)}, {stop.long.toFixed(6)}
        {stop.accuracy > 0 ? ` · ±${Math.round(stop.accuracy)} m` : ''}
      </div>
      {stop.note && <div className="mt-2 text-xs italic text-slate-600">“{stop.note}”</div>}
      {p.source === 'CORRECTION' && <div className="mt-1 text-[11px] text-amber-600 font-semibold">From a correction request</div>}
    </div>
  );
}

export default function LocationMap() {
  const [params, setParams] = useSearchParams();
  const initialUser = params.get('user');
  const [mode, setMode] = useState(initialUser ? 'USER' : 'DAY');
  const [date, setDate] = useState(params.get('date') || todayStr());
  const [month, setMonth] = useState(params.get('month') || monthStr());
  const [userId, setUserId] = useState(initialUser || '');
  const [people, setPeople] = useState([]);
  const [data, setData] = useState({ points: [], missing: [] });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [focus, setFocus] = useState(null);
  const [activeId, setActiveId] = useState(null);
  const [fitTick, setFitTick] = useState(0);

  // Employees the requester may view (scoped by the backend).
  useEffect(() => {
    api
      .get(`/attendance/all?date=${todayStr()}`)
      .then((res) => setPeople(res.data?.data || []))
      .catch(() => setPeople([]));
  }, []);

  useEffect(() => {
    let url;
    if (mode === 'DAY') url = `/attendance/map?date=${date}`;
    else {
      if (!userId) {
        setData({ points: [], missing: [] });
        return;
      }
      const [y, m] = month.split('-').map(Number);
      const last = new Date(y, m, 0).getDate();
      url = `/attendance/map?user_id=${userId}&from=${month}-01&to=${month}-${String(last).padStart(2, '0')}`;
    }
    let alive = true;
    setLoading(true);
    setError('');
    setFocus(null);
    setActiveId(null);
    api
      .get(url)
      .then((res) => alive && setData({ points: res.data?.points || [], missing: res.data?.missing || [] }))
      .catch((e) => alive && setError(e.response?.data?.error || 'Failed to load locations'))
      .finally(() => alive && setLoading(false));
    setParams(mode === 'DAY' ? { date } : { user: userId, month }, { replace: true });
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, date, month, userId]);

  const points = data.points;
  const located = points.filter((p) => p.check_in || p.check_out);
  const route = useMemo(
    () => (mode === 'USER' ? located.filter((p) => p.check_in).map((p) => [p.check_in.lat, p.check_in.long]) : []),
    [mode, located]
  );

  const shiftDate = (delta) => {
    const d = new Date(date);
    d.setDate(d.getDate() + delta);
    setDate(d.toLocaleDateString('en-CA'));
  };
  const shiftMonth = (delta) => {
    const [y, m] = month.split('-').map(Number);
    const d = new Date(y, m - 1 + delta, 1);
    setMonth(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`);
  };

  const select = (p, stop = p.check_in || p.check_out) => {
    setActiveId(p.attendance_id);
    if (stop) setFocus({ lat: stop.lat, long: stop.long, t: Date.now() });
  };

  const selectedPerson = people.find((p) => String(p.user_id) === String(userId));

  return (
    <div className="max-w-[1400px] mx-auto space-y-4">
      {/* Controls */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="inline-flex p-1 rounded-2xl bg-white border border-slate-200">
          {[
            ['DAY', 'By day', Users],
            ['USER', 'By employee', User],
          ].map(([k, label, Icon]) => (
            <button
              key={k}
              onClick={() => setMode(k)}
              className={`inline-flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-bold transition-all ${
                mode === k ? 'bg-slate-900 text-white shadow' : 'text-slate-500 hover:text-slate-900'
              }`}
            >
              <Icon className="w-4 h-4" /> {label}
            </button>
          ))}
        </div>

        {mode === 'DAY' ? (
          <div className="inline-flex items-center gap-1 bg-white border border-slate-200 rounded-2xl p-1">
            <button onClick={() => shiftDate(-1)} className="p-2 rounded-xl hover:bg-slate-100">
              <ChevronLeft className="w-4 h-4" />
            </button>
            <input
              type="date"
              value={date}
              onChange={(e) => e.target.value && setDate(e.target.value)}
              className="px-2 py-1.5 text-sm font-bold text-slate-800 bg-transparent focus:outline-none"
            />
            <button onClick={() => shiftDate(1)} className="p-2 rounded-xl hover:bg-slate-100">
              <ChevronRight className="w-4 h-4" />
            </button>
            <button onClick={() => setDate(todayStr())} className="px-3 py-1.5 rounded-xl text-xs font-bold text-brand-600 hover:bg-brand-50">
              Today
            </button>
          </div>
        ) : (
          <>
            <select
              value={userId}
              onChange={(e) => setUserId(e.target.value)}
              className="bg-white border border-slate-200 rounded-2xl px-4 py-2.5 text-sm font-bold text-slate-800 focus:outline-none focus:ring-4 focus:ring-brand-500/15"
            >
              <option value="">Choose an employee…</option>
              {people.map((p) => (
                <option key={p.user_id} value={p.user_id}>
                  {p.name} — {p.department}
                </option>
              ))}
            </select>
            <div className="inline-flex items-center gap-1 bg-white border border-slate-200 rounded-2xl p-1">
              <button onClick={() => shiftMonth(-1)} className="p-2 rounded-xl hover:bg-slate-100">
                <ChevronLeft className="w-4 h-4" />
              </button>
              <input
                type="month"
                value={month}
                onChange={(e) => e.target.value && setMonth(e.target.value)}
                className="px-2 py-1.5 text-sm font-bold text-slate-800 bg-transparent focus:outline-none"
              />
              <button onClick={() => shiftMonth(1)} className="p-2 rounded-xl hover:bg-slate-100">
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </>
        )}

        <div className="ml-auto flex items-center gap-3 text-xs font-bold text-slate-500">
          <span className="inline-flex items-center gap-1.5">
            <span className="w-3 h-3 rounded-full bg-brand-500 ring-2 ring-white shadow" /> Check-in
          </span>
          <span className="inline-flex items-center gap-1.5">
            <span className="w-3 h-3 rounded-full bg-white border-[3px] border-brand-500 shadow" /> Check-out
          </span>
        </div>
      </div>

      {error && <div className="p-3.5 rounded-2xl bg-rose-50 border border-rose-200 text-rose-700 text-sm font-semibold">{error}</div>}

      <div className="grid lg:grid-cols-[340px_1fr] gap-4">
        {/* Side list */}
        <aside className="bg-white rounded-3xl border border-slate-200/80 overflow-hidden flex flex-col h-[70vh]">
          <div className="p-4 border-b border-slate-100">
            {mode === 'DAY' ? (
              <>
                <p className="font-extrabold text-slate-900 flex items-center gap-2">
                  <CalendarDays className="w-4 h-4 text-brand-500" /> {fmtDate(date)}
                </p>
                <p className="text-xs text-slate-500 mt-0.5">
                  {located.length} checked in · {data.missing.length} without a record
                </p>
              </>
            ) : (
              <>
                <p className="font-extrabold text-slate-900 flex items-center gap-2">
                  {selectedPerson?.name || 'Select an employee'}
                  {selectedPerson && <NameBadge top={selectedPerson.top_badge} size={20} />}
                </p>
                <p className="text-xs text-slate-500 mt-0.5">{located.length} days with a location this month</p>
              </>
            )}
          </div>
          <div className="flex-1 overflow-y-auto p-2 space-y-1.5">
            {loading ? (
              <div className="flex items-center justify-center h-full text-slate-400">
                <Loader2 className="w-6 h-6 animate-spin" />
              </div>
            ) : (
              <>
                {points.map((p) => {
                  const active = activeId === p.attendance_id;
                  const color = mode === 'DAY' ? colorFor(p.user_id) : '#E11D2E';
                  return (
                    <div
                      key={p.attendance_id}
                      className={`p-3 rounded-2xl border transition-all cursor-pointer ${
                        active ? 'border-brand-500/50 bg-brand-50/60 shadow-sm' : 'border-transparent hover:bg-slate-50'
                      }`}
                      onClick={() => select(p)}
                    >
                      <div className="flex items-center gap-3">
                        <div
                          className="w-9 h-9 rounded-xl text-white text-xs font-extrabold flex items-center justify-center shrink-0"
                          style={{ background: color }}
                        >
                          {mode === 'DAY' ? initials(p.name) : new Date(p.date).getDate()}
                        </div>
                        <div className="min-w-0 flex-1">
                          <p className="text-sm font-bold text-slate-900 truncate flex items-center gap-1">
                            {mode === 'DAY' ? p.name : fmtDate(p.date)}
                            {mode === 'DAY' && <NameBadge top={p.top_badge} size={18} />}
                          </p>
                          <p className="text-[11px] text-slate-500 truncate">
                            {p.check_in?.address || (p.check_in ? 'Location without address' : 'No GPS location')}
                          </p>
                        </div>
                      </div>
                      <div className="flex gap-1.5 mt-2 pl-12">
                        <button
                          disabled={!p.check_in}
                          onClick={(e) => {
                            e.stopPropagation();
                            select(p, p.check_in);
                          }}
                          className={`inline-flex items-center gap-1 px-2 py-1 rounded-lg text-[11px] font-bold ${
                            p.status === 'LATE' ? 'bg-amber-50 text-amber-700' : 'bg-emerald-50 text-emerald-700'
                          } disabled:opacity-40`}
                        >
                          <LogIn className="w-3 h-3" /> {fmtTime(p.check_in?.time)}
                        </button>
                        <button
                          disabled={!p.check_out}
                          onClick={(e) => {
                            e.stopPropagation();
                            select(p, p.check_out);
                          }}
                          className="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-[11px] font-bold bg-violet-50 text-violet-700 disabled:opacity-40"
                        >
                          <LogOut className="w-3 h-3" /> {fmtTime(p.check_out?.time)}
                        </button>
                        {p.work_minutes > 0 && (
                          <span className="ml-auto text-[11px] font-bold text-slate-400 self-center">
                            {Math.floor(p.work_minutes / 60)}h {p.work_minutes % 60}m
                          </span>
                        )}
                      </div>
                    </div>
                  );
                })}
                {mode === 'DAY' && data.missing.length > 0 && (
                  <div className="pt-3">
                    <p className="px-2 pb-1 text-[10px] font-extrabold text-slate-400 tracking-[0.15em]">NO RECORD</p>
                    {data.missing.map((m) => (
                      <div key={m.user_id} className="px-3 py-2 flex items-center gap-2 text-sm text-slate-400">
                        <span className="w-1.5 h-1.5 rounded-full bg-slate-300" />
                        <span className="truncate">{m.name}</span>
                        <NameBadge top={m.top_badge} size={16} />
                      </div>
                    ))}
                  </div>
                )}
                {!points.length && !loading && (
                  <div className="text-center text-sm text-slate-400 py-10">
                    <MapPin className="w-8 h-8 mx-auto mb-2 text-slate-300" />
                    {mode === 'USER' && !userId ? 'Pick an employee to see their locations.' : 'No locations recorded.'}
                  </div>
                )}
              </>
            )}
          </div>
        </aside>

        {/* Map */}
        <div className="relative rounded-3xl overflow-hidden border border-slate-200/80 h-[70vh] shadow-soft">
          <MapContainer center={JAKARTA} zoom={12} className="w-full h-full" preferCanvas>
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            <FitBounds points={located} focus={focus} tick={fitTick} />
            {route.length > 1 && <Polyline positions={route} pathOptions={{ color: '#E11D2E', weight: 3, opacity: 0.5, dashArray: '6 8' }} />}
            {located.map((p) => {
              const color = mode === 'DAY' ? colorFor(p.user_id) : '#E11D2E';
              const label = mode === 'DAY' ? initials(p.name) : String(new Date(p.date).getDate());
              const active = activeId === p.attendance_id;
              return (
                <React.Fragment key={p.attendance_id}>
                  {p.check_in && p.check_out && (
                    <Polyline
                      positions={[
                        [p.check_in.lat, p.check_in.long],
                        [p.check_out.lat, p.check_out.long],
                      ]}
                      pathOptions={{ color, weight: 2, opacity: 0.6, dashArray: '4 6' }}
                    />
                  )}
                  {active && p.check_in?.accuracy > 0 && (
                    <Circle
                      center={[p.check_in.lat, p.check_in.long]}
                      radius={p.check_in.accuracy}
                      pathOptions={{ color, fillColor: color, fillOpacity: 0.1, weight: 1 }}
                    />
                  )}
                  {p.check_in && (
                    <Marker
                      position={[p.check_in.lat, p.check_in.long]}
                      icon={pinIcon(label, color, 'in', active)}
                      eventHandlers={{ click: () => setActiveId(p.attendance_id) }}
                      zIndexOffset={active ? 1000 : 0}
                    >
                      <Popup>
                        <StopPopup p={p} stop={p.check_in} kind="in" />
                      </Popup>
                    </Marker>
                  )}
                  {p.check_out && (
                    <Marker
                      position={[p.check_out.lat, p.check_out.long]}
                      icon={pinIcon(label, color, 'out', active)}
                      eventHandlers={{ click: () => setActiveId(p.attendance_id) }}
                    >
                      <Popup>
                        <StopPopup p={p} stop={p.check_out} kind="out" />
                      </Popup>
                    </Marker>
                  )}
                </React.Fragment>
              );
            })}
          </MapContainer>
          <button
            onClick={() => {
              setFocus(null);
              setActiveId(null);
              setFitTick((t) => t + 1);
            }}
            className="absolute top-3 right-3 z-[400] p-2.5 rounded-xl bg-white shadow-lg border border-slate-200 hover:bg-slate-50"
            title="Fit all pins"
          >
            <Crosshair className="w-4 h-4" />
          </button>
          {loading && (
            <div className="absolute inset-0 z-[400] bg-white/40 backdrop-blur-[1px] flex items-center justify-center">
              <Loader2 className="w-8 h-8 animate-spin text-brand-500" />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
