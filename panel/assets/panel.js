import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cfg = window.PANEL_CONFIG || {};
const db = createClient(cfg.supabaseUrl, cfg.supabaseAnonKey);

const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];

const gate = $("#gate");
const shell = $("#shell");
const errBox = $("#gate-error");

const stamp = (t) => {
  if (!t) return "-";
  const d = new Date(t), now = new Date();
  const mins = Math.round((now - d) / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return mins + "m ago";
  if (mins < 1440) return Math.round(mins / 60) + "h ago";
  return d.toLocaleDateString(undefined, { day: "numeric", month: "short" });
};

const tickClock = () => {
  $("#clock").textContent = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
};

$("#signin").addEventListener("submit", async (e) => {
  e.preventDefault();
  const btn = $("#signin-btn");
  errBox.hidden = true;
  btn.disabled = true;
  btn.textContent = "Signing in...";

                              const { error } = await db.auth.signInWithPassword({
                                email: cfg.sharedAccount,
                                password: $("#password").value
                              });

                              btn.disabled = false;
  btn.textContent = "Sign in";

                              if (error) {
                                errBox.textContent = "That password does not match. Nothing was sent anywhere.";
                                errBox.hidden = false;
                                $("#password").select();
                                return;
                              }
  open();
});

$("#signout").addEventListener("click", async () => {
  await db.auth.signOut();
  shell.hidden = true;
  gate.hidden = false;
  $("#password").value = "";
});

async function open() {
  gate.hidden = true;
  shell.hidden = false;
  tickClock();
  setInterval(tickClock, 30000);
  await refresh();
  setInterval(refresh, 60000);
}

$("#tabs").addEventListener("click", (e) => {
  const t = e.target.closest(".tab");
  if (!t) return;
  $$(".tab").forEach((x) => x.classList.toggle("is-on", x === t));
  $$(".view").forEach((v) => v.classList.toggle("is-on", v.dataset.view === t.dataset.view));
});

async function refresh() {
  await Promise.all([loadMethod(), loadIdentity(), loadLeases(), loadRefused()]);
}

async function loadMethod() {
  const { data, error } = await db
  .from("fact")
  .select("id,key,value,note,status,origin,observed_at,revision")
  .eq("namespace", "method")
  .in("status", ["current", "proposed", "superseded"]);

const list = $("#method-list");
  if (error) return fail(list, error.message);
  if (!data || !data.length) return blank(list, "Nothing here yet. Method arrives when the first rule is written.");

const proposed = data.filter((r) => r.status === "proposed");
  $("#proposals-wrap").hidden = proposed.length === 0;
  $("#proposal-count").textContent = proposed.length;

const order = { proposed: 0, current: 1, superseded: 2 };
  list.innerHTML = data
  .sort((a, b) => order[a.status] - order[b.status] || a.key.localeCompare(b.key))
  .map((r) => '<article class="entry is-' + r.status + '">' +
    '<p class="entry-key">' + esc(r.key) + '</p>' +
    '<p class="entry-rule">' + esc(r.value && r.value.rule ? r.value.rule : JSON.stringify(r.value)) + '</p>' +
    (r.note ? '<p class="entry-note">' + esc(r.note) + '</p>' : '') +
    '<p class="entry-meta">' +
    '<span class="pill ' + r.status + '">' + r.status + '</span>' +
    '<span>' + (r.revision ? 'rev ' + r.revision : 'no revision') + '</span>' +
    '<span>' + esc(r.origin) + '</span>' +
    '<span>' + stamp(r.observed_at) + '</span>' +
    '</p></article>').join("");
}

$("#promote-all").addEventListener("click", async (e) => {
  e.target.disabled = true;
  const { data } = await db.from("fact").select("id").eq("namespace", "method").eq("status", "proposed");
  for (const row of data || []) await db.rpc("fact_promote", { p_fact_id: row.id });
  e.target.disabled = false;
  loadMethod();
});

async function loadIdentity() {
  const { data, error } = await db
  .from("identity")
  .select("handle,kind,label,owner,purpose,dispatchable,profile_path,account,last_registered_at")
  .order("kind").order("handle");

const box = $("#identity-list");
  if (error) return fail(box, error.message);
  if (!data || !data.length) return blank(box, "No machines, surfaces or targets registered. Until something registers, it is not a participant - and work will not be sent to it.");

box.innerHTML = data.map((r) => '<div class="card">' +
  '<div class="card-top"><span class="card-name">' + esc(r.handle) + '</span>' +
  '<span class="mono dim">' + esc(r.kind) + (r.dispatchable ? '' : ' - not dispatchable') + '</span></div>' +
  (r.label ? '<p class="card-detail">' + esc(r.label) + '</p>' : '') +
  (r.purpose ? '<p class="card-detail dim">' + esc(r.purpose) + '</p>' : '') +
  (r.profile_path ? '<p class="mono dim">' + esc(r.profile_path) + '</p>' : '') +
  '<p class="mono dim">' + esc(r.owner) + ' - seen ' + stamp(r.last_registered_at) + '</p>' +
  '</div>').join("");
}

async function loadLeases() {
  const { data, error } = await db
  .from("lease")
  .select("task,acquired_at,expires_at,target(handle,label),holder(handle)")
  .is("released_at", null)
  .order("acquired_at", { ascending: false });

const box = $("#lease-list");
  if (error) return fail(box, error.message);
  if (!data || !data.length) return blank(box, "Nothing held. Every target is idle, and every target is therefore off limits until a task names it.");

box.innerHTML = data.map((r) => '<div class="card">' +
  '<div class="card-top"><span class="card-name">' + esc(r.target ? r.target.handle : "-") + '</span>' +
  '<span class="pill held">held</span></div>' +
  '<p class="card-detail">' + esc(r.task) + '</p>' +
  '<p class="mono dim">by ' + esc(r.holder ? r.holder.handle : "unknown") + ' - since ' + stamp(r.acquired_at) + ' - expires ' + stamp(r.expires_at) + '</p>' +
  '</div>').join("");
}

async function loadRefused() {
  const { data, error } = await db
  .from("write_attempt")
  .select("at,namespace,key,reason,detail,origin")
  .order("at", { ascending: false })
  .limit(50);

const box = $("#rejected-list");
  if (error) return fail(box, error.message);
  if (!data || !data.length) return blank(box, "No writes refused. Nothing has tried to put old information over new.");

box.innerHTML = data.map((r) => '<div class="row"><div>' +
  '<span class="mono">' + esc(r.namespace) + '.' + esc(r.key) + '</span>' +
  '<p class="card-detail dim">' + esc(r.detail || "") + '</p></div>' +
  '<div style="text-align:right">' +
  '<span class="row-reason">' + esc(r.reason) + '</span>' +
  '<p class="mono dim">' + esc(r.origin || "") + ' - ' + stamp(r.at) + '</p>' +
  '</div></div>').join("");
}

const esc = (s) => String(s === null || s === undefined ? "" : s).replace(/[&<>"']/g, (c) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
}[c]));

const blank = (el, msg) => { el.innerHTML = '<p class="empty">' + msg + '</p>'; };
const fail = (el, msg) => { el.innerHTML = '<p class="empty">Could not read that: ' + esc(msg) + '</p>'; };

db.auth.getSession().then(({ data }) => { if (data.session) open(); });
$("#gate-status").textContent = cfg.supabaseUrl ? "ready" : "config.js not set";
