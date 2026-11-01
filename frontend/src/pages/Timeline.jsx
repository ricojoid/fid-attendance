import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Heart, MessageCircle, ImagePlus, X, Send, Trash2, Loader2 } from 'lucide-react';
import api from '../api/client';
import { useAuth } from '../context/AuthContext';
import AvatarFrame from '../components/AvatarFrame';
import { NameBadge } from '../components/BadgeMedal';

const mediaBase = (import.meta.env.VITE_API_URL || '/api/v1').replace(/\/api\/v1\/?$/, '');
const mediaUrl = (p) => (!p || p.startsWith('http') ? p : `${mediaBase}${p}`);

function timeAgo(iso) {
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)}m`;
  if (s < 86400) return `${Math.floor(s / 3600)}h`;
  if (s < 604800) return `${Math.floor(s / 86400)}d`;
  return new Date(iso).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' });
}

/** Downscale a photo before upload (max 1600px, JPEG). */
function resizeForUpload(file, max = 1600) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      const k = Math.min(1, max / Math.max(img.width, img.height));
      const w = Math.round(img.width * k);
      const h = Math.round(img.height * k);
      const c = document.createElement('canvas');
      c.width = w;
      c.height = h;
      c.getContext('2d').drawImage(img, 0, 0, w, h);
      URL.revokeObjectURL(url);
      c.toBlob((b) => (b ? resolve({ blob: b, w, h }) : reject(new Error('Could not process image'))), 'image/jpeg', 0.82);
    };
    img.onerror = () => reject(new Error('Unsupported image'));
    img.src = url;
  });
}

function Composer({ me, onPosted }) {
  const [text, setText] = useState('');
  const [photo, setPhoto] = useState(null); // {blob, w, h, preview}
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const fileRef = useRef(null);

  const pick = async (e) => {
    const f = e.target.files?.[0];
    e.target.value = '';
    if (!f) return;
    try {
      const r = await resizeForUpload(f);
      setPhoto({ ...r, preview: URL.createObjectURL(r.blob) });
    } catch (err) {
      setError(err.message);
    }
  };

  const post = async () => {
    if (!text.trim() && !photo) return;
    setBusy(true);
    setError('');
    try {
      const fd = new FormData();
      fd.append('text', text.trim());
      if (photo) {
        fd.append('image', photo.blob, 'photo.jpg');
        fd.append('image_w', photo.w);
        fd.append('image_h', photo.h);
      }
      const res = await api.post('/timeline/posts', fd, { headers: { 'Content-Type': 'multipart/form-data' }, timeout: 60000 });
      onPosted(res.data);
      setText('');
      if (photo) URL.revokeObjectURL(photo.preview);
      setPhoto(null);
    } catch (e) {
      setError(e.response?.data?.error || 'Failed to publish');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="bg-white rounded-3xl border border-slate-200/80 p-5 shadow-soft">
      <div className="flex gap-3">
        <AvatarFrame frame={me?.avatar_frame} src={me?.avatar_url} name={me?.name} size={42} />
        <div className="flex-1">
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            maxLength={2000}
            rows={text ? 3 : 2}
            placeholder={`What did you do today, ${me?.name?.split(' ')[0] || ''}? 🚀`}
            className="w-full resize-none bg-transparent text-[15px] text-slate-900 placeholder:text-slate-400 focus:outline-none"
          />
          {photo && (
            <div className="relative mt-2 inline-block animate-scale-in">
              <img src={photo.preview} alt="" className="max-h-72 rounded-2xl object-cover" />
              <button onClick={() => setPhoto(null)} className="absolute top-2 right-2 p-1.5 rounded-full bg-black/60 text-white hover:bg-black/80">
                <X className="w-4 h-4" />
              </button>
            </div>
          )}
          {error && <p className="text-sm text-rose-600 font-semibold mt-2">{error}</p>}
          <div className="flex items-center gap-2 mt-3 pt-3 border-t border-slate-100">
            <button onClick={() => fileRef.current?.click()} className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl text-sm font-bold text-brand-600 bg-brand-50 hover:bg-brand-100 transition-colors">
              <ImagePlus className="w-4 h-4" /> Photo
            </button>
            <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={pick} />
            <span className="ml-auto text-xs text-slate-400">{text.length}/2000</span>
            <button
              onClick={post}
              disabled={busy || (!text.trim() && !photo)}
              className="inline-flex items-center gap-1.5 px-5 py-2 rounded-xl text-sm font-extrabold text-white bg-gradient-to-br from-brand-400 to-brand-700 shadow-glow disabled:opacity-40 active:scale-95 transition-all"
            >
              {busy ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />} Post
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

function Comments({ post, authors, onCount }) {
  const [list, setList] = useState(null);
  const [extraAuthors, setExtraAuthors] = useState({});
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api.get(`/timeline/posts/${post.id}/comments`).then((r) => {
      setList(r.data.comments || []);
      setExtraAuthors(r.data.authors || {});
    });
  }, [post.id]);

  const send = async (e) => {
    e.preventDefault();
    if (!text.trim()) return;
    setBusy(true);
    try {
      const r = await api.post(`/timeline/posts/${post.id}/comments`, { text: text.trim() });
      setList((l) => [...(l || []), r.data.comment]);
      onCount(1);
      setText('');
    } finally {
      setBusy(false);
    }
  };

  const who = (id) => extraAuthors[id] || authors[id] || {};
  return (
    <div className="px-5 pb-4 animate-fade-in">
      <div className="space-y-2.5 max-h-72 overflow-y-auto">
        {list === null ? (
          <Loader2 className="w-5 h-5 animate-spin text-slate-400" />
        ) : (
          list.map((c) => (
            <div key={c.id} className="flex gap-2.5">
              <AvatarFrame frame={who(c.user_id).avatar_frame} src={who(c.user_id).avatar_url} name={who(c.user_id).name} size={28} animate={false} />
              <div className="bg-slate-50 rounded-2xl px-3 py-2">
                <p className="text-xs font-extrabold text-slate-900">
                  {who(c.user_id).name} <span className="font-semibold text-slate-400">· {timeAgo(c.created_at)}</span>
                </p>
                <p className="text-sm text-slate-700">{c.text}</p>
              </div>
            </div>
          ))
        )}
      </div>
      <form onSubmit={send} className="flex gap-2 mt-3">
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          maxLength={500}
          placeholder="Add a comment…"
          className="flex-1 px-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-sm focus:outline-none focus:ring-4 focus:ring-brand-500/15 focus:border-brand-500"
        />
        <button disabled={busy || !text.trim()} className="p-2.5 rounded-2xl bg-gradient-to-br from-brand-400 to-brand-700 text-white disabled:opacity-40">
          <Send className="w-4 h-4" />
        </button>
      </form>
    </div>
  );
}

function PostCard({ post, authors, onDelete }) {
  const a = authors[post.user_id] || {};
  const [liked, setLiked] = useState(post.liked_by_me);
  const [likes, setLikes] = useState(post.like_count);
  const [comments, setComments] = useState(post.comment_count);
  const [showComments, setShowComments] = useState(false);
  const [burst, setBurst] = useState(0);
  const [zoom, setZoom] = useState(false);

  const toggle = async (fromDouble = false) => {
    if (fromDouble) {
      setBurst((b) => b + 1);
      if (liked) return;
    }
    setLiked((v) => !v);
    setLikes((n) => n + (liked ? -1 : 1));
    try {
      const r = await api.post(`/timeline/posts/${post.id}/like`);
      setLiked(r.data.liked);
      setLikes(r.data.like_count);
    } catch (_) {
      /* keep optimistic state */
    }
  };

  const ratio = post.image_w && post.image_h ? Math.min(1.9, Math.max(0.6, post.image_w / post.image_h)) : 4 / 3;
  return (
    <article className="group bg-white rounded-3xl border border-slate-200/80 shadow-soft overflow-hidden">
      <header className="flex items-center gap-3 px-5 pt-4 pb-3">
        <AvatarFrame frame={a.avatar_frame} src={a.avatar_url} name={a.name} size={40} animate={false} />
        <div className="min-w-0 flex-1">
          <p className="font-extrabold text-slate-900 flex items-center gap-1.5 truncate">
            {a.name} <NameBadge top={a.top_badge} size={20} />
          </p>
          <p className="text-xs text-slate-400 font-semibold">
            {a.department} · {timeAgo(post.created_at)}
          </p>
        </div>
        {post.can_delete && (
          <button
            onClick={() => window.confirm('Delete this post?') && onDelete(post.id)}
            className="p-2 rounded-xl text-slate-400 hover:text-rose-600 hover:bg-rose-50 opacity-0 group-hover:opacity-100 transition-all"
            title="Delete post"
          >
            <Trash2 className="w-4 h-4" />
          </button>
        )}
      </header>
      {post.text && <p className="px-5 pb-3 text-[15px] text-slate-800 whitespace-pre-wrap leading-relaxed">{post.text}</p>}
      {post.image_url && (
        <div className="relative mx-3 rounded-2xl overflow-hidden bg-slate-100 cursor-zoom-in" style={{ aspectRatio: ratio }} onDoubleClick={() => toggle(true)} onClick={() => setZoom(true)}>
          <img src={mediaUrl(post.image_url)} alt="" loading="lazy" decoding="async" className="w-full h-full object-cover" />
          {burst > 0 && (
            <Heart key={burst} className="absolute inset-0 m-auto w-24 h-24 text-white fill-white drop-shadow-xl heart-burst pointer-events-none" />
          )}
        </div>
      )}
      <div className="flex items-center gap-1 px-3 py-2">
        <button onClick={() => toggle()} className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl hover:bg-rose-50 transition-colors">
          <Heart key={String(liked)} className={`w-5 h-5 ${liked ? 'text-rose-500 fill-rose-500 like-pop' : 'text-slate-500'}`} />
          <span className="text-sm font-bold text-slate-600">{likes}</span>
        </button>
        <button onClick={() => setShowComments((v) => !v)} className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl hover:bg-slate-50 transition-colors">
          <MessageCircle className="w-5 h-5 text-slate-500" />
          <span className="text-sm font-bold text-slate-600">{comments}</span>
        </button>
      </div>
      {!showComments && post.comments?.length > 0 && (
        <button onClick={() => setShowComments(true)} className="block text-left px-5 pb-4 space-y-1 w-full">
          {post.comments.map((c) => (
            <p key={c.id} className="text-sm text-slate-600 truncate">
              <b className="text-slate-900">{authors[c.user_id]?.name}</b> {c.text}
            </p>
          ))}
          {comments > post.comments.length && <p className="text-xs font-bold text-slate-400">View all {comments} comments</p>}
        </button>
      )}
      {showComments && <Comments post={post} authors={authors} onCount={(n) => setComments((x) => x + n)} />}
      {zoom && (
        <div className="fixed inset-0 z-[70] bg-black/90 flex items-center justify-center p-6 animate-fade-in cursor-zoom-out" onClick={() => setZoom(false)}>
          <img src={mediaUrl(post.image_url)} alt="" className="max-w-full max-h-full rounded-xl animate-scale-in" />
        </div>
      )}
    </article>
  );
}

export default function Timeline() {
  const { user } = useAuth();
  const [posts, setPosts] = useState([]);
  const [authors, setAuthors] = useState({});
  const [next, setNext] = useState(null);
  const [loading, setLoading] = useState(true);
  const sentinel = useRef(null);
  const loadingMore = useRef(false);

  const load = useCallback(async (before) => {
    const res = await api.get('/timeline', { params: { limit: 15, ...(before ? { before } : {}) } });
    setAuthors((a) => ({ ...a, ...(res.data.authors || {}) }));
    setPosts((p) => (before ? [...p, ...(res.data.posts || [])] : res.data.posts || []));
    setNext(res.data.next_before || null);
  }, []);

  useEffect(() => {
    load().finally(() => setLoading(false));
  }, [load]);

  // Infinite scroll.
  useEffect(() => {
    if (!sentinel.current) return undefined;
    const io = new IntersectionObserver(async ([e]) => {
      if (e.isIntersecting && next && !loadingMore.current) {
        loadingMore.current = true;
        await load(next);
        loadingMore.current = false;
      }
    });
    io.observe(sentinel.current);
    return () => io.disconnect();
  }, [next, load]);

  return (
    <div className="max-w-2xl mx-auto space-y-5">
      <div>
        <h1 className="text-3xl font-extrabold tracking-tight text-slate-900">Timeline</h1>
        <p className="text-sm text-slate-500">What's everyone up to today?</p>
      </div>
      <Composer
        me={user}
        onPosted={(d) => {
          setAuthors((a) => ({ ...a, ...(d.authors || {}) }));
          setPosts((p) => [d.post, ...p]);
        }}
      />
      {loading ? (
        [0, 1, 2].map((i) => <div key={i} className="h-72 rounded-3xl bg-slate-200/60 animate-pulse" />)
      ) : posts.length === 0 ? (
        <div className="text-center py-16 text-slate-400 font-semibold">No posts yet — be the first to share your day!</div>
      ) : (
        <div className="space-y-5 stagger">
          {posts.map((p) => (
            <PostCard
              key={p.id}
              post={p}
              authors={authors}
              onDelete={async (id) => {
                await api.delete(`/timeline/posts/${id}`);
                setPosts((list) => list.filter((x) => x.id !== id));
              }}
            />
          ))}
        </div>
      )}
      <div ref={sentinel} className="h-8" />
    </div>
  );
}
