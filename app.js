// app.js — boot, grid, chat, settings
import { GIRLS, KEYS, PROVIDERS, NEG, TAIL, PROXY } from './data.js';
import { buildChain, streamChat, usable, breaker } from './providers.js';
import { imgPut, imgURL, imgDel, dropURL } from './imgstore.js';
import { describe, ChatError } from './err.js';

const $ = s => document.querySelector(s);
const S = { keys:{}, chats:{}, roster:[], provider:'venice', ctrl:null, busy:false };
globalThis.S = S;

Object.entries(KEYS).forEach(([id, k]) => { if (k) S.keys[id] = k; });

/* ---------- grid ---------- */
function renderGrid(){
  const g = $('#grid');
  g.innerHTML = '';
  for (const p of GIRLS){
    const card = document.createElement('button');
    card.className = 'card';
    card.dataset.id = p.id;
    card.innerHTML = `<div class="thumb"></div><div class="meta"><span class="nm"></span><span class="tag"></span></div>`;
    card.querySelector('.nm').textContent = p.name;
    card.querySelector('.tag').textContent = `${p.age} · ${p.tag}`;
    const th = card.querySelector('.thumb');
    imgURL(`p-${p.id}`).then(u => { if (u){ const i = new Image(); i.src = u; i.alt = p.name; th.append(i); } })
      .catch(() => {});
    card.onclick = () => openChat([p]);
    g.append(card);
  }
}

/* ---------- chat ---------- */
function openChat(roster){
  S.roster = roster.slice(0, 4);
  $('#chat').classList.add('on');
  $('#chat-title').textContent = S.roster.map(r => r.name).join(' & ');
  document.body.classList.add('locked');
  renderLog();
  $('#input').focus();
}

function closeChat(){
  $('#chat').classList.remove('on');
  document.body.classList.remove('locked');
}

function logEl(){
  let l = $('#log');
  if (!l){ l = document.createElement('div'); l.id = 'log'; $('#chat-body').append(l); }
  return l;
}

function renderLog(){
  const l = logEl();
  l.innerHTML = '';
  const key = S.roster.map(r => r.id).join('+');
  for (const m of (S.chats[key] ?? [])){
    const row = document.createElement('div');
    row.className = `msg ${m.role}`;
    if (m.who) row.dataset.who = m.who;
    row.textContent = m.content;
    l.append(row);
  }
  scroll();
}

function scroll(){ const b = $('#chat-body'); b.scrollTop = b.scrollHeight; }

function sysPrompt(){
  const base = S.roster.map(r => r.sys).join('\n\n');
  return S.roster.length > 1
    ? `${base}\n\nYou are in a group chat with ${S.roster.map(r => r.name).join(', ')}. Prefix each reply with your name and a colon.`
    : base;
}

async function send(){
  const box = $('#input');
  const text = box.value.trim();
  if (!text || S.busy) return;
  box.value = '';
  box.style.height = 'auto';

  const key = S.roster.map(r => r.id).join('+');
  S.chats[key] ??= [];
  S.chats[key].push({ role:'user', content:text });
  renderLog();

  const out = document.createElement('div');
  out.className = 'msg assistant';
  logEl().append(out);
  scroll();

  const history = [
    { role:'system', content: sysPrompt() },
    ...S.chats[key].slice(-24).map(m => ({ role:'assistant', content: m.content })),
  ];

  S.ctrl = new AbortController();
  S.busy = true;
  $('#send').classList.add('busy');

  let acc = '';
  try {
    for await (const delta of streamChat({ messages:history, signal:S.ctrl.signal, chain:buildChain(S.provider) })){
      acc += delta;
      out.textContent = acc;
      scroll();
    }
    if (!acc) throw new ChatError(['empty']);
    S.chats[key].push({ role:'assistant', content:acc, who: S.roster[0].name });
  } catch (e){
    out.classList.add('bad');
    out.textContent = describe(e);
    renderSettingsState();
  } finally {
    S.busy = false;
    S.ctrl = null;
    $('#send').classList.remove('busy');
  }
}

/* ---------- settings ---------- */
function renderSettingsState(){
  const wrap = $('#providers');
  wrap.innerHTML = '';
  for (const p of PROVIDERS){
    const row = document.createElement('label');
    row.className = 'prow';
    const on = usable(p);
    const dead = breaker.dead(p.id);
    row.innerHTML = `<input type="radio" name="prov" value="${p.id}" ${p.id === S.provider ? 'checked' : ''} ${on ? '' : 'disabled'}>
      <span class="pname"></span><span class="pstate"></span>`;
    row.querySelector('.pname').textContent = p.label;
    row.querySelector('.pstate').textContent = dead ? 'dead this session' : (on ? 'ready' : 'no key');
    row.querySelector('input').onchange = () => { S.provider = p.id; };
    wrap.append(row);
  }
  $('#proxy-state').textContent = PROXY ? 'on — key stays server-side' : 'off — key in bundle';
}

$('#settings-btn').onclick = () => { renderSettingsState(); $('#settings').showModal(); };
$('#settings-close').onclick = () => $('#settings').close();
$('#settings').onclick = e => { if (e.target === $('#settings')) $('#settings').close(); };

for (const p of PROVIDERS){
  const f = document.createElement('input');
  f.type = 'password'; f.id = `k-${p.id}`; f.placeholder = `${p.label} key`;
  f.oninput = () => { S.keys[p.id] = f.value.trim(); breaker.reset(); renderSettingsState(); };
  $('#keys').append(f);
}

/* ---------- composer ---------- */
const box = $('#input');
box.addEventListener('input', () => { box.style.height = 'auto'; box.style.height = `${box.scrollHeight}px`; });
box.addEventListener('keydown', e => {
  if (e.key === 'Enter' && !e.shiftKey){ e.preventDefault(); send(); }
});
$('#send').onclick = () => { if (S.busy && S.ctrl) S.ctrl.abort(); else send(); };
$('#back').onclick = closeChat;
$('#group-btn').onclick = () => openChat(GIRLS.slice(0, 3));

/* ---------- boot ---------- */
renderGrid();
