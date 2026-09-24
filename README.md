# SecureGate: Shift-Left Secrets & IaC Security Guardrail for CI/CD

A PR-blocking security pipeline that catches leaked secrets, misconfigured Infrastructure-as-Code, vulnerable dependencies, and insecure code — **before** they ever get merged, not after they're deployed.

---

## 1. Problem Statement

Most teams bolt security on *after* deployment — a scanner finds a leaked API key in production, or an auditor flags an open S3 bucket that's been live for months. By then the damage (credential leak, non-compliant infra, data exposure) is already done, and fixing it means an incident response process, not a code review comment.

**The root cause:** nothing stops a bad commit from being merged in the first place.

**What this project builds:** a shift-left security gate that runs automatically on every pull request and:
- Blocks secrets (API keys, tokens, credentials) from ever being committed
- Blocks Terraform/IaC misconfigurations (open security groups, unencrypted storage, public buckets) before they're applied
- Flags vulnerable dependencies before they ship
- Flags insecure code patterns (SAST) before merge
- Surfaces every finding directly as an inline PR comment, so the fix happens in the same review cycle
- Physically blocks the merge button until critical/high findings are resolved (branch protection + required status check)

This is the difference between "DevOps with a scanner" and actual DevSecOps: the pipeline enforces policy, it doesn't just report on violations after the fact.

---

## 2. Architecture

```
Developer                GitHub                      CI/CD (GitHub Actions)
┌──────────┐         ┌─────────────┐            ┌──────────────────────────────┐
│  git add │         │             │            │  Job 1: Gitleaks (secrets)   │
│  commit  │───pre───▶  Pull       │──trigger──▶│  Job 2: Checkov + tfsec (IaC)│
│  (hooks) │  commit │  Request    │            │  Job 3: Trivy (SCA/deps)     │
└──────────┘         │             │            │  Job 4: Semgrep (SAST)       │
                      └─────────────┘            └───────────────┬──────────────┘
                             ▲                                    │
                             │                            inline PR comments
                             │                          (reviewdog / GitHub API)
                             │                                    │
                      ┌──────┴──────┐                             ▼
                      │  Branch     │◀────── required status check must pass
                      │  Protection │
                      │  (merge     │──── on FAIL: merge blocked, Slack alert
                      │   gate)     │──── on PASS: merge allowed
                      └─────────────┘
```

**Design principle:** every check that runs in CI also runs locally via pre-commit hooks, so developers get instant feedback and CI is a backstop, not the first line of defense.

---

## 3. Tech Stack

| Layer | Tool | Purpose |
|---|---|---|
| Secret detection | [Gitleaks](https://github.com/gitleaks/gitleaks) | Scans for hardcoded credentials, API keys, tokens |
| IaC security | [Checkov](https://www.checkov.io/) + [tfsec](https://github.com/aquasecurity/tfsec) | Scans Terraform for misconfigurations |
| Dependency scanning (SCA) | [Trivy](https://github.com/aquasecurity/trivy) | Scans dependencies/lockfiles for known CVEs |
| Static code analysis (SAST) | [Semgrep](https://semgrep.dev/) | Scans source code for insecure patterns |
| Local enforcement | [pre-commit](https://pre-commit.com/) framework | Runs the same scanners before commit |
| CI orchestration | GitHub Actions | Runs all scans in parallel on every PR |
| PR feedback | [reviewdog](https://github.com/reviewdog/reviewdog) or GitHub API script | Posts inline PR comments on findings |
| Merge enforcement | GitHub Branch Protection Rules | Blocks merge until required checks pass |
| Alerting (stretch) | Slack Incoming Webhook | Notifies channel on blocked PR |
| Dashboard (stretch) | Static HTML on S3, or GitHub Pages | Historical scan summary |

---

## 4. Repository Structure

```
securegate/
├── .github/
│   └── workflows/
│       ├── security-scan.yml       # Phase 2-3: main CI pipeline
│       └── pr-comment.yml          # Phase 4: PR bot comments
├── .pre-commit-config.yaml         # Phase 1: local hooks
├── terraform/
│   ├── good-example/               # passes IaC scan (for demo)
│   └── bad-example/                # intentionally vulnerable (for demo)
├── app/
│   └── sample-vulnerable-app/      # small app with a planted CVE + secret for demo
├── scripts/
│   ├── post_pr_comment.py          # Phase 4: GitHub API comment poster
│   └── notify_slack.py             # Phase 6: Slack webhook
├── docs/
│   ├── architecture.png
│   └── screenshots/
└── README.md
```

---

## 5. Project Phases

Each phase is independently completable and demo-able. Finish and verify one before moving to the next — each phase alone is enough to show working, useful security tooling.

### **Phase 0 — Repo & Demo App Setup**
**Goal:** have something worth scanning.
- Create the repo with the structure above
- Add a small sample app (any language you're comfortable in — FastAPI is fine, matches your existing stack)
- Add a `terraform/bad-example` directory with an intentionally insecure resource (e.g. a security group open to `0.0.0.0/0` on port 22, an unencrypted S3 bucket)
- Add a `terraform/good-example` with the fixed, secure version of the same resource
- Deliberately commit a fake secret (e.g. a dummy AWS key) into the demo app so Phase 1/2 have something real to catch — **never use a real credential**

**Done when:** repo exists with a demo app + intentionally-vulnerable Terraform + a planted fake secret.

**Concepts learned:** repo hygiene, structuring a security demo so findings are reproducible and explainable in an interview.

---

### **Phase 1 — Local Pre-Commit Guardrails**
**Goal:** catch issues before they're even pushed.
- Install the `pre-commit` framework
- Configure hooks for Gitleaks (secrets) and Checkov (Terraform)
- Run `pre-commit run --all-files` and confirm it catches the planted secret and the bad Terraform resource
- Document how a developer installs this locally (`pre-commit install`)

**Done when:** `git commit` on the planted secret is blocked locally, before it ever reaches GitHub.

**Concepts learned:** shift-left security, git hooks, why local enforcement matters even when CI exists (fast feedback loop, doesn't waste CI minutes on preventable issues).

---

### **Phase 2 — CI Pipeline: Secrets + IaC Scanning**
**Goal:** the same checks running automatically on every PR, as a backstop.
- Write a GitHub Actions workflow (`security-scan.yml`) triggered on `pull_request`
- Add parallel jobs for Gitleaks and Checkov/tfsec
- Configure each job to fail the workflow on critical/high findings
- Push a PR with the planted secret and confirm the workflow fails

**Done when:** opening a PR with the planted secret or bad Terraform shows a red ❌ check on GitHub.

**Concepts learned:** GitHub Actions job/workflow syntax, matrix/parallel jobs, exit-code-based gating, why CI enforcement matters even with local hooks (hooks can be skipped with `--no-verify`; CI can't be bypassed).

---

### **Phase 3 — Dependency (SCA) + Static Code (SAST) Scanning**
**Goal:** extend coverage beyond secrets/IaC to code and dependencies.
- Add a Trivy job scanning the app's dependency lockfile for known CVEs
- Add a Semgrep job scanning the app source for insecure patterns (e.g. SQL injection, hardcoded crypto keys, unsafe deserialization)
- Deliberately add one vulnerable dependency version and one insecure code pattern to the demo app to prove detection

**Done when:** all four scan types (secrets, IaC, SCA, SAST) run on every PR and each can be demonstrated catching a real planted issue.

**Concepts learned:** difference between SAST and SCA, CVE severity scoring (CVSS), why scanning code and scanning dependencies are separate concerns.

---

### **Phase 4 — Inline PR Comments (the "bot")**
**Goal:** findings show up where developers actually look — on the PR diff, not buried in CI logs.
- Use `reviewdog` (easiest) **or** write a small Python script using the GitHub REST API to parse scanner output (SARIF or JSON) and post inline review comments on the offending lines
- Test that a finding in `terraform/bad-example` produces a comment directly on that line in the PR

**Done when:** a PR with a violation shows an automated review comment pointing at the exact line, with a short explanation.

**Concepts learned:** GitHub REST API / Checks API, SARIF format (the standard security-tooling output format), building lightweight developer-experience tooling around raw scanner output.

---

### **Phase 5 — Branch Protection Merge Gate**
**Goal:** make the pipeline actually enforce policy, not just report.
- In GitHub repo settings, add a branch protection rule on `main`
- Require the `security-scan` workflow as a required status check
- Disable "allow merge without passing checks" (no admin override, to prove the gate is real)
- Test: confirm the merge button is disabled on a PR with a failing scan, and enabled once fixed

**Done when:** it is physically impossible to merge a PR with an unresolved critical/high finding.

**Concepts learned:** branch protection rules, required status checks, the difference between a pipeline that reports vs. one that enforces — this is the core "DevSecOps" concept for the whole project.

---

### **Phase 6 — Slack Alerting (stretch)**
**Goal:** visibility beyond the PR itself.
- Create a Slack Incoming Webhook
- Add a step/script that posts a message to Slack when a PR is blocked, including repo, PR link, and which scan failed

**Done when:** a blocked PR produces a Slack notification within seconds.

**Concepts learned:** webhook-based integrations, alerting design (what's worth alerting on vs. noise).

---

### **Phase 7 — Scan History Dashboard (stretch)**
**Goal:** show security posture over time, not just per-PR.
- Have the CI workflow append scan results (pass/fail, finding counts, timestamp) to a simple JSON/CSV log, stored in S3 or committed to a `results/` branch
- Render it as a static HTML page (a simple table or chart) — GitHub Pages or S3 static hosting both work
- Bonus: a trend chart of findings-per-week

**Done when:** you have a link you can show in an interview: "here's our security posture over the last month."

**Concepts learned:** turning point-in-time scan results into a metric/trend, basic security reporting — this is what separates a portfolio demo from something that reads like real team tooling.

---

## 6. Setup & Usage

```bash
# clone
git clone https://github.com/<you>/securegate.git
cd securegate

# install local pre-commit hooks (Phase 1)
pip install pre-commit
pre-commit install

# run all scans locally, on demand
pre-commit run --all-files

# CI runs automatically on every PR via .github/workflows/security-scan.yml
```

---

## 7. What This Demonstrates (for interviews)

- **Shift-left security**: catching issues at commit-time and PR-time, not deploy-time
- **Policy-as-code enforcement**: the pipeline blocks, it doesn't just warn
- **Multi-layer scanning**: secrets, IaC, dependencies, and code — the four pillars of a real AppSec/DevSecOps pipeline
- **Developer experience**: findings surface inline, where developers already work, not buried in a separate dashboard nobody checks
- **CI/CD security integration**: GitHub Actions, branch protection, and required status checks used as actual enforcement mechanisms, not decoration

---

## 8. License

MIT
