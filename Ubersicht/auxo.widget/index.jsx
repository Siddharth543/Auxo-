// Auxo for Übersicht: GitHub, LeetCode and Codeforces streak heatmaps on the Mac desktop.
// No Xcode, no signing, no Apple Developer account. Edit the CONFIG block below and save.

// ===================== CONFIG =====================
const ACCOUNTS = [
  { source: "codeforces", handle: "tourist" },   // replace with your handles
  { source: "leetcode",   handle: "your_leetcode_name" },
  { source: "github",     handle: "your_github_login" },
];
// Needed only for GitHub. Create a fine-grained token with public-repo access and NO permissions:
// https://github.com/settings/personal-access-tokens/new
const GITHUB_TOKEN = "";

const LAYOUT = "stacked";     // "stacked" (one heatmap per account) or "combined" (one grid)
const SHOW_HANDLES = false;   // keep false if you screenshot your desktop
const CELL = 10;              // cell size in px
const GAP = 3;                // gap between cells in px
const WEEKS = 53;
// ==================================================

const SOURCES = {
  codeforces: { name: "Codeforces", palette: ["#1b1f26", "#17335c", "#1f5bb5", "#3b82f6", "#7db3ff"] },
  leetcode:   { name: "LeetCode",   palette: ["#1b1f26", "#4a3510", "#8a5f10", "#e6a020", "#ffc95c"] },
  github:     { name: "GitHub",     palette: ["#1b1f26", "#0e4429", "#006d32", "#26a641", "#39d353"] },
};
const COMBINED_PALETTE = ["#1b1f26", "#3b2a63", "#5b3fa6", "#8b6bdc", "#c4b1ff"];

// Official Codeforces ladder (brightened where the real color is too dark for a dark surface).
const CF_RANKS = [
  { min: 3000, title: "Legendary Grandmaster", color: "#ff4d4d", legendary: true },
  { min: 2600, title: "International Grandmaster", color: "#ff4d4d" },
  { min: 2400, title: "Grandmaster", color: "#ff4d4d" },
  { min: 2300, title: "International Master", color: "#ffa733" },
  { min: 2100, title: "Master", color: "#ffa733" },
  { min: 1900, title: "Candidate Master", color: "#e072e0" },
  { min: 1600, title: "Expert", color: "#6f8bff" },
  { min: 1400, title: "Specialist", color: "#2ec9b4" },
  { min: 1200, title: "Pupil", color: "#4cc24c" },
  { min: -Infinity, title: "Newbie", color: "#a0a0a0" },
];
const cfRank = (r) => CF_RANKS.find((x) => r >= x.min);

const SAFE = /^[A-Za-z0-9_.-]+$/;
const TOKEN_SAFE = /^[A-Za-z0-9_]*$/;

const GH_QUERY = "query($login:String!){user(login:$login){contributionsCollection{contributionCalendar{weeks{contributionDays{date contributionCount}}}}}}";
const LC_QUERY = "query($u:String!){matchedUser(username:$u){userCalendar{submissionCalendar}} userContestRanking(username:$u){rating badge{name}}}";

const valid = ACCOUNTS.filter((a) => SOURCES[a.source] && SAFE.test(a.handle || ""));

const curlFor = (a, i) => {
  const mark = (part) => `echo "@@${i}|${part}"`;
  if (a.source === "codeforces") {
    return [
      mark("info"), `curl -s --max-time 20 "https://codeforces.com/api/user.info?handles=${a.handle}"`,
      "sleep 2.1",
      mark("status"), `curl -s --max-time 30 "https://codeforces.com/api/user.status?handle=${a.handle}"`,
    ].join("; ");
  }
  if (a.source === "leetcode") {
    const body = JSON.stringify({ query: LC_QUERY, variables: { u: a.handle } });
    return [
      mark("lc"),
      `curl -s --max-time 20 -H "Content-Type: application/json" -H "Referer: https://leetcode.com/u/${a.handle}/" -d '${body}' https://leetcode.com/graphql`,
    ].join("; ");
  }
  if (!TOKEN_SAFE.test(GITHUB_TOKEN) || !GITHUB_TOKEN) return mark("nogithubtoken");
  const body = JSON.stringify({ query: GH_QUERY, variables: { login: a.handle } });
  return [
    mark("gh"),
    `curl -s --max-time 20 -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Content-Type: application/json" -d '${body}' https://api.github.com/graphql`,
  ].join("; ");
};

export const command = valid.map(curlFor).join("; ");
export const refreshFrequency = 30 * 60 * 1000;

export const className = `
  top: 40px;
  left: 40px;
  font-family: -apple-system, "SF Pro Text", "Helvetica Neue", sans-serif;
  color: #e6edf3;
  user-select: none;
`;

// ---------- parsing ----------
const pad = (n) => String(n).padStart(2, "0");
const localKey = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const utcKey = (d) => `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;

const sections = (output) => {
  const out = {};
  let cur = null;
  for (const line of String(output).split("\n")) {
    const m = line.match(/^@@(\d+)\|(\w+)$/);
    if (m) { cur = `${m[1]}|${m[2]}`; out[cur] = ""; } else if (cur) out[cur] += line;
  }
  return out;
};
const json = (s) => { try { return JSON.parse(s); } catch (e) { return null; } };

const parseAccount = (a, i, sec) => {
  if (a.source === "codeforces") {
    const info = json(sec[`${i}|info`]), st = json(sec[`${i}|status`]);
    if (!st || st.status !== "OK") throw new Error((st && st.comment) || "Codeforces unavailable");
    const counts = {};
    for (const s of st.result) {
      if (s.verdict !== "OK") continue;
      const k = localKey(new Date(s.creationTimeSeconds * 1000));
      counts[k] = (counts[k] || 0) + 1;
    }
    const u = info && info.status === "OK" ? info.result[0] : null;
    const rating = u && u.rating != null ? { value: u.rating, max: u.maxRating, ...cfRank(u.rating) } : null;
    return { counts, rating };
  }
  if (a.source === "leetcode") {
    const r = json(sec[`${i}|lc`]);
    const user = r && r.data && r.data.matchedUser;
    if (!user) throw new Error("LeetCode unavailable");
    const cal = json(user.userCalendar && user.userCalendar.submissionCalendar) || {};
    const counts = {};
    for (const [ts, n] of Object.entries(cal)) counts[utcKey(new Date(+ts * 1000))] = n;
    const c = r.data.userContestRanking;
    const rating = c && c.rating ? { value: Math.round(c.rating), title: c.badge && c.badge.name, color: "#ffc95c" } : null;
    return { counts, rating };
  }
  if (sec[`${i}|nogithubtoken`] !== undefined) throw new Error("Set GITHUB_TOKEN in the widget file");
  const r = json(sec[`${i}|gh`]);
  const weeks = r && r.data && r.data.user && r.data.user.contributionsCollection.contributionCalendar.weeks;
  if (!weeks) throw new Error("GitHub unavailable (check token)");
  const counts = {};
  for (const w of weeks) for (const d of w.contributionDays) if (d.contributionCount) counts[d.date] = d.contributionCount;
  return { counts, rating: null };
};

export const initialState = { loading: true, data: {}, errors: {}, updated: null };

export const updateState = (event, prev) => {
  if (event.error) return { ...prev, loading: false, errors: { _: "Network error" } };
  const sec = sections(event.output);
  const data = { ...prev.data }, errors = {};
  valid.forEach((a, i) => {
    try { data[i] = parseAccount(a, i, sec); } catch (e) { errors[i] = e.message; }  // keep last good data
  });
  return { loading: false, data, errors, updated: Date.now() };
};

// ---------- grid math ----------
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const level = (n) => (n === 0 ? 0 : n === 1 ? 1 : n <= 3 ? 2 : n <= 6 ? 3 : 4);

const buildGrid = (counts) => {
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const start = new Date(today);
  start.setDate(start.getDate() - (WEEKS - 1) * 7 - today.getDay());
  const cells = [], months = [];
  let total = 0;
  for (let d = new Date(start), i = 0; i < WEEKS * 7; d.setDate(d.getDate() + 1), i++) {
    const future = d > today, n = future ? 0 : counts[localKey(d)] || 0;
    cells.push({ key: localKey(d), n, future, label: d.toDateString() });
    total += n;
    if (d.getDate() <= 7 && d.getDay() === 0) months.push({ col: i / 7, text: MONTHS[d.getMonth()] });
  }
  // Streak counts back from yesterday if nothing has happened yet today.
  let streak = 0;
  const cur = new Date(today);
  if (!counts[localKey(cur)]) cur.setDate(cur.getDate() - 1);
  while (counts[localKey(cur)]) { streak++; cur.setDate(cur.getDate() - 1); }
  return { cells, months, total, streak };
};

// ---------- view ----------
const box = {
  background: "rgba(13, 17, 23, 0.78)", backdropFilter: "blur(14px)", WebkitBackdropFilter: "blur(14px)",
  border: "1px solid rgba(255,255,255,0.08)", borderRadius: 14, padding: "14px 16px", marginBottom: 10,
};
const step = CELL + GAP;

const Grid = ({ grid, palette, unit }) => (
  <div>
    <div style={{ position: "relative", height: 13, width: WEEKS * step }}>
      {grid.months.map((m) => (
        <span key={m.col} style={{ position: "absolute", left: m.col * step, fontSize: 9, opacity: 0.55 }}>{m.text}</span>
      ))}
    </div>
    <div style={{ display: "grid", gridTemplateRows: `repeat(7, ${CELL}px)`, gridAutoFlow: "column", gridAutoColumns: `${CELL}px`, gap: GAP }}>
      {grid.cells.map((c) => (
        <div key={c.key} title={`${c.n} ${unit} on ${c.label}`}
          style={{ width: CELL, height: CELL, borderRadius: 2, background: palette[level(c.n)], visibility: c.future ? "hidden" : "visible" }} />
      ))}
    </div>
  </div>
);

const RatingLine = ({ rating }) => {
  if (!rating) return null;
  return (
    <span style={{ fontSize: 12, fontWeight: 600, color: rating.color }}>
      {rating.title ? `${rating.title} · ` : ""}{rating.value}
    </span>
  );
};

const Card = ({ a, i, state }) => {
  const src = SOURCES[a.source], res = state.data[i], err = state.errors[i];
  if (!res) return <div style={box}>{src.name}: {err || "Loading…"}</div>;
  const grid = buildGrid(res.counts);
  const unit = a.source === "github" ? "contributions" : a.source === "leetcode" ? "submissions" : "accepted";
  return (
    <div style={box}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 8 }}>
        <div style={{ fontSize: 13, fontWeight: 600 }}>
          {src.name}{SHOW_HANDLES ? <span style={{ opacity: 0.55, fontWeight: 400 }}> · {a.handle}</span> : null}
        </div>
        <div style={{ display: "flex", gap: 12, alignItems: "baseline" }}>
          <RatingLine rating={res.rating} />
          <span style={{ fontSize: 11, opacity: 0.75 }}>{grid.total} {unit} · 🔥 {grid.streak}</span>
        </div>
      </div>
      <Grid grid={grid} palette={src.palette} unit={unit} />
      {err ? <div style={{ fontSize: 10, opacity: 0.6, marginTop: 6 }}>⚠️ {err} (showing last data)</div> : null}
    </div>
  );
};

const Combined = ({ state }) => {
  const live = valid.map((a, i) => state.data[i]).filter(Boolean);
  if (!live.length) return <div style={box}>{state.loading ? "Loading…" : Object.values(state.errors)[0]}</div>;
  // A day's shade is how many accounts were active, so 30 commits don't drown out 2 solved problems.
  const merged = {};
  for (const r of live) for (const k of Object.keys(r.counts)) merged[k] = (merged[k] || 0) + 1;
  const grid = buildGrid(merged);
  return (
    <div style={box}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 8, fontSize: 13, fontWeight: 600 }}>
        <span>All streaks</span><span style={{ fontSize: 11, opacity: 0.75, fontWeight: 400 }}>🔥 {grid.streak}</span>
      </div>
      <Grid grid={grid} palette={COMBINED_PALETTE} unit="active accounts" />
    </div>
  );
};

export const render = (state) => {
  if (!valid.length) return <div style={box}>Add at least one valid account in auxo.widget/index.jsx</div>;
  return (
    <div>
      {LAYOUT === "combined" ? <Combined state={state} /> : valid.map((a, i) => <Card key={i} a={a} i={i} state={state} />)}
      <div style={{ fontSize: 10, opacity: 0.45, paddingLeft: 4 }}>
        {state.updated ? `Updated ${new Date(state.updated).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}` : ""}
      </div>
    </div>
  );
};
