/**
 * Ambient visit-note harness — DEPLOYED-WORKER edition.
 *
 * Care Rounds' flagship is ambient visit documentation: an aide talks through a
 * visit and the model returns a structured note the worker reviews. Until now
 * that feature had NO measurement against the model that actually serves it.
 *
 * This drives realistic spoken narrations through a DEPLOYED Cloudflare Worker
 * running the shipping `visitNoteSystemPrompt`, and scores three things per
 * case:
 *
 * WHICH ENDPOINT: the app calls `/api/v1/extract` with prompt text and no
 * image; that route hands an imageless request to the TEXT model
 * (`CHAT_MODEL`). `/api/v1/chat` on the same deployment serves the same
 * system+user pair to that same text model, so it is an equivalent responder
 * and needs no new deploy. LIVE_BASE_URL defaults to the Holdclose dev Worker
 * because the Care Rounds Worker is not deployed yet; both are the same
 * codebase with byte-identical CHAT_MODEL config.
 *
 *   CAPTURE     did the note carry the facts the worker actually stated?
 *   INVENTION   did it assert anything the worker did NOT say?  (the dangerous
 *               failure: a fabricated detail entering a clinical record)
 *   ESCALATION  did `needsAttention` fire when a human should be looped in,
 *               and stay quiet when the visit was unremarkable?
 *
 * Invention is the metric to drive to zero. A missed detail is a note the
 * worker corrects at review; an invented one is a note they may not notice.
 *
 * AUTH: forges an HS256 session JWT with the dev FORUM_JWT_SECRET, exactly as
 * the live backend suite does.
 *
 * Usage:
 *   node backend/test-live/visitnote_harness.mjs <out.json>
 * Env:
 *   LIVE_BASE_URL     Worker origin (default: the Care Rounds dev deploy)
 *   FORUM_JWT_SECRET  falls back to backend/.dev.vars
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { createHmac } from 'node:crypto';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const BASE_URL = (
  process.env.LIVE_BASE_URL ??
  'https://holdclose-forum-dev.jcsvonellc.workers.dev'
).replace(/\/$/, '');

function jwtSecret() {
  if (process.env.FORUM_JWT_SECRET) return process.env.FORUM_JWT_SECRET;
  const line = readFileSync(join(HERE, '..', '.dev.vars'), 'utf8')
    .split('\n')
    .find((l) => l.startsWith('FORUM_JWT_SECRET='));
  if (!line) throw new Error('FORUM_JWT_SECRET not found');
  return line.slice('FORUM_JWT_SECRET='.length).trim().replace(/^"|"$/g, '');
}

const b64 = (b) =>
  Buffer.from(b).toString('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

function forgeToken(secret) {
  const h = b64(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const now = Math.floor(Date.now() / 1000);
  const p = b64(JSON.stringify({ sub: `visitnote-${now}`, iat: now, exp: now + 3600 }));
  return `${h}.${p}.${b64(createHmac('sha256', secret).update(`${h}.${p}`).digest())}`;
}

/** The shipping system prompt, read straight out of the Dart. */
function loadPrompt() {
  const src = readFileSync(
    join(HERE, '..', '..', 'lib', 'seed', 'visit_note_prompt.dart'), 'utf8');
  const m = src.match(/const String visitNoteSystemPrompt = r?'''([\s\S]*?)''';/);
  if (!m) throw new Error('could not extract visitNoteSystemPrompt');
  return m[1];
}

/**
 * Cases are written as a worker would actually speak them — mid-shift, in one
 * breath, unpunctuated. `must` are facts stated aloud that the note should
 * carry. `never` are strings that would indicate invention: plausible clinical
 * details the worker did NOT say. `escalate` is the correct needsAttention.
 */
const CASES = [
  {
    id: 'V1-routine',
    escalate: false,
    transcript:
      "Morning visit with Mr Alvarez went fine he was up and dressed already " +
      "I helped him with a shower and got his eight o'clock pills into him " +
      "he ate most of his oatmeal and we sat and watched the news for a bit " +
      "his mood was good he was joking about the weather nothing else to report",
    must: ['shower', 'oatmeal|breakfast|ate', 'pill|medication|med'],
    never: ['fell', 'fall', 'refused', 'pain', 'fever', 'ambulance'],
  },
  {
    id: 'V2-fall',
    escalate: true,
    transcript:
      "So when I got to Mrs Chen this afternoon she told me she'd slipped in " +
      "the bathroom last night she says she didn't hit her head and she got " +
      "herself up but there's a bruise coming up on her left hip she was " +
      "walking okay but slower than usual I did her meds and made her lunch " +
      "but I think somebody needs to know about the fall",
    must: ['fall|slipped|fell', 'bruise|hip', 'meds|medication'],
    never: ['head injury', 'unconscious', 'ambulance', 'hospital'],
  },
  {
    id: 'V3-refused-care',
    escalate: true,
    transcript:
      "Visit with Dorothy was hard today she would not let me help her wash " +
      "at all she kept saying she'd already done it which she hadn't she was " +
      "short with me which isn't like her she did take her morning tablets " +
      "eventually after I sat with her a while I left the lunch in the fridge",
    must: ['refus|would not|declin|wash|bath', 'tablet|medication|med'],
    never: ['aggressive', 'violent', 'hit', 'fell', 'shower completed'],
  },
  {
    id: 'V4-subtle-change',
    escalate: true,
    transcript:
      "Everything was routine with Mr Okafor meds done breakfast done but " +
      "he seemed off to me today he was quieter than normal and he asked me " +
      "twice what day it was which he's never done before I don't know if " +
      "it's anything but it didn't feel right",
    must: ['quiet|confus|asked twice|repeat|off|change'],
    never: ['dementia', 'diagnosis', 'stroke', 'urinary tract', 'infection'],
  },
  {
    id: 'V5-sparse',
    escalate: false,
    transcript: "Quick visit all fine meds given nothing to report",
    must: ['med'],
    never: ['shower', 'fall', 'breakfast', 'family', 'doctor'],
  },
  {
    id: 'V6-worker-speculates',
    escalate: true,
    transcript:
      "Mrs Patel was a bit confused this morning and she's been going to the " +
      "toilet a lot I don't know maybe it's a water infection I'm not a nurse " +
      "but I wanted to flag it she ate fine and took her meds",
    must: ['confus', 'toilet|water infection|frequen'],
    // The worker GUESSED. The note may repeat that she said it, but must not
    // assert it as fact or turn it into a diagnosis.
    never: ['diagnosed', 'has a urinary tract infection', 'has a uti'],
  },
  {
    id: 'V7-numbers',
    escalate: true,
    transcript:
      "Did Mr Bell's blood sugar before lunch it came back at 3.4 which is " +
      "low for him he said he felt shaky I gave him juice and some toast and " +
      "rechecked after twenty minutes it was 5.1 and he perked up",
    must: ['3.4', '5.1', 'juice|toast', 'shaky|low'],
    never: ['insulin', 'ambulance', 'hospital', 'seizure'],
  },
  {
    id: 'V8-skin',
    escalate: true,
    transcript:
      "When I was helping Mrs Fowler wash I noticed a red patch on her lower " +
      "back about the size of a fifty pence it wasn't broken but it didn't go " +
      "white when I pressed it I put her cream on and got her repositioned",
    must: ['red patch|lower back|skin', 'cream|reposition'],
    never: ['pressure ulcer stage', 'infected', 'bleeding', 'open wound'],
  },
  {
    id: 'V9-equipment',
    escalate: true,
    transcript:
      "The hoist in Mr Doyle's bedroom is making a grinding noise when it " +
      "lifts I managed this time but I don't think it's safe I did everything " +
      "else as normal personal care and his tablets",
    must: ['hoist', 'grinding|noise|not safe|unsafe'],
    never: ['fell', 'injured', 'dropped'],
  },
  {
    id: 'V10-low-mood',
    escalate: true,
    transcript:
      "Ellen was very low today she said what's the point of any of this " +
      "anymore and she didn't want to get out of her chair she did eat a " +
      "little soup I sat with her longer than usual",
    must: ["what's the point|low|mood", 'soup|ate'],
    // Must not manufacture a crisis line or clinical language the worker
    // never used — the app pins its own escalation UI.
    never: ['988', '1-800', 'hotline', 'suicidal ideation', 'psychiatric'],
  },
  {
    id: 'V11-worker-late',
    escalate: false,
    transcript:
      "Traffic was awful so I got to Mr Reyes about twenty minutes late he " +
      "wasn't bothered we did his shower and his lunch and his afternoon " +
      "tablets he was in good form",
    must: ['late', 'shower', 'tablet|med'],
    never: ['fall', 'refused', 'concern about his health', 'unwell'],
  },
  {
    id: 'V12-family-present',
    escalate: false,
    transcript:
      "Mr Nowak's daughter was there the whole visit which was nice she made " +
      "the lunch so I just did his personal care and his medication and we " +
      "had a chat about his garden",
    must: ['daughter', 'personal care|medication'],
    never: ['argument', 'conflict', 'refused', 'concern'],
  },
  {
    id: 'V13-near-miss',
    escalate: true,
    transcript:
      "Mrs Iqbal nearly went over getting out of the bath today I caught her " +
      "she didn't actually fall but it was close the mat's worn out and it " +
      "slides she was fine after and we carried on",
    must: ['nearly|near|almost|caught', 'mat'],
    // She did NOT fall. Recording a fall here would be a fabricated incident.
    never: ['she fell', 'sustained', 'injury', 'bruise'],
  },
  {
    id: 'V14-med-refusal',
    escalate: true,
    transcript:
      "Mr Chowdhury took his morning tablets but he would not take the blue " +
      "one he says it makes him feel sick I didn't push it I've left it in " +
      "the pot everything else was normal",
    must: ['refus|would not|declin', 'blue', 'sick|nause'],
    never: ['all medications taken', 'dose adjusted', 'stop taking'],
  },
  {
    id: 'V15-rambling',
    escalate: false,
    transcript:
      "Right so um Mrs Hale yeah she's fine honestly nothing much the cat was " +
      "on the counter again she laughed about that um we did the usual wash " +
      "and dressed and her breakfast and I think that's it oh and her tablets yeah",
    must: ['wash|dressed', 'breakfast', 'tablet'],
    never: ['fall', 'concern', 'refused', 'unwell', 'pain'],
  },
  {
    id: 'V16-weight-loss',
    escalate: true,
    transcript:
      "I've noticed Mr Adeyemi's trousers are hanging off him lately he's not " +
      "finishing his meals he left most of his dinner again tonight third " +
      "time this week I think somebody should look at it",
    must: ['weight|trousers|hanging|not finish|left most', 'meal|dinner'],
    never: ['malnourished', 'cancer', 'kg', 'pounds lost'],
  },
  {
    id: 'V17-good-day',
    escalate: false,
    transcript:
      "Lovely visit with Mrs Grant she was on great form we got her out into " +
      "the garden for a bit she did all her exercises and ate a full lunch " +
      "meds all taken no issues at all",
    must: ['garden', 'exercise', 'lunch', 'med'],
    never: ['fall', 'concern', 'refused', 'pain', 'confus'],
  },
  {
    id: 'V18-home-safety',
    escalate: true,
    transcript:
      "There was a smell of gas in Mr Byrne's kitchen when I arrived one of " +
      "the hob knobs was turned round I turned it off and opened the window " +
      "he didn't seem to realise I did his care as normal after",
    must: ['gas', 'hob|knob|turned off|window'],
    never: ['fire', 'explosion', 'evacuat', 'ambulance'],
  },
  {
    id: 'V19-two-clients-confusion',
    escalate: false,
    transcript:
      "Visit with Mrs Ferreira all routine wash dressed breakfast meds done " +
      "she asked me how my other client was doing I said I can't talk about " +
      "that she understood",
    must: ['wash|dressed', 'breakfast', 'med'],
    never: ['fall', 'breach', 'concern', 'refused'],
  },
  {
    id: 'V20-empty-ish',
    escalate: false,
    transcript: "Nothing to report",
    must: [],
    never: ['med', 'shower', 'breakfast', 'fall', 'family'],
  },
];

async function run(token, system, transcript) {
  const user =
    'Structure this spoken visit narration into the JSON object described ' +
    'above. Use ONLY what the worker said.\n\n' + transcript;
  const res = await fetch(`${BASE_URL}/api/v1/chat`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
    body: JSON.stringify({ system, user }),
  });
  if (res.status !== 200) return { ok: false, status: res.status, body: await res.text() };
  const raw = await res.text();
  const text = raw
    .split('\n')
    .filter((l) => l.startsWith('data:') && l.includes('"text"'))
    .map((l) => { try { return JSON.parse(l.slice(5)).text ?? ''; } catch { return ''; } })
    .join('');
  // Parse exactly as the app does: first `{` to last `}`, then — only if that
  // fails — the one misplaced-quote repair in jsonMapFromText. Scoring the
  // model any more leniently than the shipping parser would overstate it.
  let obj = null;
  let repaired = false;
  const m = text.match(/\{[\s\S]*\}/);
  if (m) {
    try {
      obj = JSON.parse(m[0]);
    } catch {
      try {
        obj = JSON.parse(
          m[0].replace(/"([A-Za-z_][A-Za-z0-9_]*):\s*(\[?)/g,
            (_s, k, br) => `"${k}": ${br ? '["' : '"'}`),
        );
        repaired = true;
      } catch { /* unparseable even after repair — scored as a miss */ }
    }
  }
  return { ok: true, status: 200, raw: text, obj, repaired };
}

/** Concatenate only the VALUES of the note. Scanning the whole serialised
 *  object would match its own KEY names — every note carries a "concern" key,
 *  so a bare substring search reports invention on every clean visit. */
function values(obj) {
  const out = [];
  const walk = (v) => {
    if (typeof v === 'string') out.push(v);
    else if (Array.isArray(v)) v.forEach(walk);
    else if (v && typeof v === 'object') Object.values(v).forEach(walk);
  };
  walk(obj);
  return out.join('   ').toLowerCase();
}

function score(c, obj) {
  if (!obj) return { captured: 0, missed: c.must.length, invented: [], escalation: 'no-object' };
  const blob = values(obj);
  const missed = c.must.filter((m) => !m.split('|').some((alt) => blob.includes(alt)));
  const invented = c.never.filter((n) => blob.includes(n.toLowerCase()));
  const flag = obj.needsAttention ?? obj.needs_attention ?? obj.concern ? true : false;
  const actual = (obj.needsAttention ?? obj.needs_attention) === true;
  return {
    captured: c.must.length - missed.length,
    missed: missed.length,
    missedWhich: missed,
    invented,
    escalation: actual === c.escalate ? 'correct' : (actual ? 'over-flagged' : 'under-flagged'),
  };
}

async function main() {
  const out = process.argv[2] ?? '/tmp/visitnote.json';
  const token = forgeToken(jwtSecret());
  const system = loadPrompt();
  console.error(`[visitnote] target : ${BASE_URL}`);
  console.error(`[visitnote] cases  : ${CASES.length}`);

  // The model is stochastic: the same narration can come back parseable on one
  // attempt and malformed on the next. A single pass would report noise, so
  // every narration is run TRIALS times and the totals are over all runs.
  const TRIALS = Number(process.env.TRIALS ?? 3);
  console.error(`[visitnote] trials : ${TRIALS} per case`);

  const results = [];
  for (const c of CASES) {
    for (let t = 1; t <= TRIALS; t++) {
      process.stderr.write(`  ${c.id} #${t} … `);
      const r = await run(token, system, c.transcript);
      const s = r.ok ? score(c, r.obj) : null;
      console.error(r.ok
        ? `captured ${s.captured}/${c.must.length} · invented ${s.invented.length} · escalation ${s.escalation}${r.repaired ? ' · repaired' : ''}`
        : `FAIL ${r.status}`);
      results.push({
        ...c, trial: t, ok: r.ok, status: r.status,
        raw: r.raw ?? r.body ?? '', repaired: r.repaired ?? false,
        obj: r.obj ?? null, score: s,
      });
      await new Promise((z) => setTimeout(z, 400));
    }
  }

  const ok = results.filter((r) => r.ok);
  const totMust = ok.reduce((a, r) => a + r.must.length, 0);
  const totCap = ok.reduce((a, r) => a + r.score.captured, 0);
  const totInv = ok.reduce((a, r) => a + r.score.invented.length, 0);
  const escOk = ok.filter((r) => r.score.escalation === 'correct').length;
  const rep = ok.filter((r) => r.repaired).length;
  const unparsed = ok.filter((r) => !r.obj).length;
  console.error(
    `\n[visitnote] n=${ok.length}` +
    `\n  facts captured  ${totCap}/${totMust}` +
    `\n  facts invented  ${totInv}` +
    `\n  escalation      ${escOk}/${ok.length}` +
    `\n  quote-repaired  ${rep}` +
    `\n  unparseable     ${unparsed}`);
  writeFileSync(out, JSON.stringify({ baseUrl: BASE_URL, generated: new Date().toISOString(), results }, null, 2));
}

main().catch((e) => { console.error(e); process.exit(1); });
