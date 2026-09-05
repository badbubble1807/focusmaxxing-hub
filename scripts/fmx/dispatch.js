// focusmaxxing hub - start the "build hub" cloud build from this PC and watch it finish.
// plain node, no packages. the github token comes from the git credential helper
// (the same one git push uses), it is never printed.
//
// usage: node scripts/fmx/dispatch.js            start a build and watch it
//        node scripts/fmx/dispatch.js watch      only watch the newest run
const { execSync } = require("child_process");

const REPO = "badbubble1807/focusmaxxing-hub";
const WORKFLOW = "build-hub.yml";
const BRANCH = "main";

const cred = execSync("git credential fill", { input: "protocol=https\nhost=github.com\n", encoding: "utf8" });
const token = cred.split("\n").find(l => l.startsWith("password=")).slice("password=".length);
const headers = { Authorization: "Bearer " + token, "User-Agent": "focusmaxxing", Accept: "application/vnd.github+json", "Content-Type": "application/json" };

async function api(method, path, body) {
  const r = await fetch("https://api.github.com/repos/" + REPO + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const text = await r.text();
  let json = null; try { json = JSON.parse(text); } catch {}
  return { status: r.status, json, text };
}
const sleep = ms => new Promise(r => setTimeout(r, ms));
const stamp = () => new Date().toTimeString().slice(0, 8);

(async () => {
  const watchOnly = process.argv[2] === "watch";
  let before = new Set();
  if (!watchOnly) {
    const runs = await api("GET", "/actions/workflows/" + WORKFLOW + "/runs?per_page=5");
    for (const run of (runs.json && runs.json.workflow_runs) || []) before.add(run.id);
    const d = await api("POST", "/actions/workflows/" + WORKFLOW + "/dispatches", { ref: BRANCH });
    if (d.status !== 204) { console.error("could not start the build:", d.status, d.text.slice(0, 300)); process.exit(1); }
    console.log(stamp(), "build requested");
  }
  // find the run
  let run = null;
  for (let i = 0; i < 24 && !run; i++) {
    await sleep(5000);
    const runs = await api("GET", "/actions/workflows/" + WORKFLOW + "/runs?per_page=5");
    const list = (runs.json && runs.json.workflow_runs) || [];
    run = watchOnly ? list[0] : list.find(r => !before.has(r.id));
  }
  if (!run) { console.error("no run appeared"); process.exit(1); }
  console.log(stamp(), "run #" + run.run_number, run.html_url);
  // watch it
  let last = "";
  while (true) {
    await sleep(30000);
    const r = await api("GET", "/actions/runs/" + run.id);
    const j = r.json || {};
    const line = j.status + (j.conclusion ? "/" + j.conclusion : "");
    if (line !== last) { console.log(stamp(), line); last = line; }
    if (j.status === "completed") {
      if (j.conclusion !== "success") {
        const jobs = await api("GET", "/actions/runs/" + run.id + "/jobs");
        for (const job of (jobs.json && jobs.json.jobs) || []) {
          const failed = (job.steps || []).filter(s => s.conclusion === "failure").map(s => s.name);
          console.log("job", job.name, job.conclusion, failed.length ? "failed steps: " + failed.join(", ") : "");
        }
        process.exit(2);
      }
      const rel = await api("GET", "/releases/tags/hub");
      for (const a of (rel.json && rel.json.assets) || []) console.log("release asset:", a.name, Math.round(a.size / 1e6) + " MB", a.browser_download_url);
      process.exit(0);
    }
  }
})().catch(e => { console.error("error:", e.message); process.exit(1); });
