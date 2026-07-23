insert into identity (kind, anchor, handle, label, owner, dispatchable, purpose)
values ('surface','seed','seed','Migration seed','shared',false,'initial method load')
on conflict (handle) do nothing;

with me as (select id from identity where handle = 'seed'),
r(k, v, note) as (values
  ('targeting.explicit_only',
  '{"rule":"A task drives only the targets it named. Everything else is denied, however reachable. Reachability never implies eligibility."}',
  'A task may hold several targets at once on one machine; a machine that is merely switched on is not a participant in that task.'),
  ('identity.anchor',
  '{"rule":"Identity anchors to something the user cannot casually change. Machines: hardware UUID, with serial recorded for human verification. Targets: profile path. Never hostname, never MAC, never a positional index."}',
  'MAC rejected: several per machine, Wi-Fi randomises per network, and a shared dock makes two machines present the same address.'),
  ('recency.arbitration',
  '{"rule":"Recency is decided by revision and observation time, never by a machine clock. A write must name the row it supersedes and may not carry an older observation time."}',
  'Stops a last-run setup overwriting new information with old.'),
  ('provenance.claude_proposes',
  '{"rule":"Anything a Claude asserts is marked as such and is not truth until it is promoted."}',
  'A stale Claude belief about which work was current steered a design session wrong for three exchanges before it was caught.'),
  ('presentation.no_opaque_ids',
  '{"rule":"Never present an identifier the user did not choose. Lists shown to a human carry registry names or real-world evidence - account, path, window title. Positional indices are internal only."}',
  'Browser 1..4 is unanswerable by a human, and the numbers reorder between listings.'),
  ('claims.verify_before_asserting',
  '{"rule":"Never claim a file or record changed unless the run log confirms it."}',
  'Carried forward from the existing dispatch guide.'),
  ('lifecycle.seed_then_graduate',
  '{"rule":"A project draws from the central store at the start, then graduates to a pinned standalone copy. Its main functions must run with no Claude and no central dependency. Tracking resumes when a Claude session links in."}',
  'Central being unavailable must never stop a project working.'),
  ('asking.look_before_asking',
  '{"rule":"Never ask the user something the available sources can answer. Query the store, the database, the filesystem or the API first. Asking in place of looking is a defect."}',
  'A whole session was steered wrong by asserting stale beliefs and then asking about them instead of reading the data.'),
  ('asking.decide_what_is_reversible',
  '{"rule":"Where a choice is reversible and the user has said proceed, choose a sensible default, act, and report what was chosen."}',
  'Region, naming and ordering are noise; surface them as decisions taken, not questions.'),
  ('asking.reserved_for_the_user',
  '{"rule":"Always stop and ask for: spending money, credentials and tokens, account creation, and irreversible deletion. Batch them into one list up front."}',
  'These are the only asks that should survive.')
  )
select (fact_write('method', r.k, r.v::jsonb, now(), 'claude', null, me.id, r.note)).key
from r, me;
