# Olie Workflow Policy — Host-card & env

Load this module for host-card ensure/open/destroy, CAPTCHA, payments, production URL, private e2e, language/formatting.

Index: `~/git/olie/prompts/workflow-policy.md`

## Host card environment

Cards run as **host units** on jarvis. Contract: `~/git/host-cards-no-vm.md`. CLI: `~/git/bin/workvm-host-card`.

**Ensure (start or resume — multi-day):** at the beginning of `implementation.md`, `correction.md`, `colleague-review.md`, and `production-review.md`, **before** git checkout, board moves that need a local stack, or heavy review work: (suite regression is manager **Pest** — no agent ensure for that gate)

```bash
~/git/bin/workvm-host-card ensure --project olie --code '{{ code }}'
```

User phrase **`open olie {{ code }}`** (see **Chat commands** in `workflow-policy/gates.md`): `workvm-host-card open` (= ensure + **focus/open** the card `.code-workspace`). Always print `workspace=` and `api_worktree=`. Rebases/edits belong in that worktree’s `api-main`, **not** `~/git/olie/api-main`. Do not leave the user on the meta-repo `~/git` Cursor window.

**Meta-repo on host-card (any project):** edit, commit, and push only under the workspace folder **`git/`** (detached card meta worktree). Do **not** write bare `~/git/…` for content — outside workspace, duplicates state, permission prompts. Resolve `~/git/...` in prompts to that `git/` root (same pattern as **Private E2E suites** → workspace `olie-e2e`). Rule: `host-card-meta-repo-path.mdc`. **Exception:** edit bare `~/git` only if the user **explicitly** asks. Push with `git push origin HEAD:<live-branch>` (live name from `git -C ~/git branch --show-current`); then `git -C ~/git pull --ff-only` so runtime stays current — meta commit/push still agent-owned on the card `git/` worktree (Pre-QA script does not auto-commit meta). Binaries may still run from `~/git/bin/…`; product clones may land under `GIT_ROOT=~/git`.

**api-main hooks:** ensure wires `workvm-host-card-captainhook` on the card worktree. Commitlint/CaptainHook for handoff = manager **Pre-QA** (agent does not loop SHAs by hand).

- **Shell permissions (required):** call `ensure` / `open` / `destroy` **and** `~/git/bin/workvm-sandbox` (`create` / `job run` / `destroy`) / coverage·mutation drains **on the first attempt** with unrestricted agent shell — `required_permissions: ["all"]`. Never probe them in the default sandbox “to see if it works” (DOP-1136: first ensure without `all` → Permission denied on `mcp.json`/`meta.json` and a false “host broken” stop). Host-card workspaces live under `~/.local/share/workvm/host-cards/…`; sandboxes write `~/.local/share/workvm/sandboxes/` (outside those roots) + `docker.sock` — the default agent sandbox always denies both.
  - **Sandbox symptom cluster** (sandbox only — **not** a broken jarvis host): `PermissionError` / `Permission denied` writing `~/.cursor/mcp.json` or `~/.local/share/workvm/`; `github.com` DNS timeout / `could not read Username for 'https://github.com'`; missing `/var/run/docker.sock` **while `pgrep dockerd` is alive**; empty stub `resolv.conf`; or `gh` “token invalid” **only in that agent shell**. The same command succeeds with `all` when the host is fine. Ensure may print `WORKVM_AGENT_SANDBOX=1` and exit `75`.
  - **Silent sandbox after `all`:** if the Shell tool footer still says the command ran sandboxed (or ensure hits the cluster / exit 75) despite `required_permissions: ["all"]`, Auto-review likely auto-approved the tool call **without elevating**. Next: (1) `request_smart_mode_approval` on the **exact** ensure/sandbox command; (2) if still sandboxed, `~/git/bin/workvm-host-card agent-ensure --project … --code …` (bridge systemd outside the agent — install once with `install-agent-bridge` under a real unrestricted shell); (3) when the stack is already up but `docker.sock` is still hidden, `~/git/bin/workvm-host-card agent-docker --project … --code … --container <service|name> -- <cmd>…` (bridge `docker exec` for Pest/artisan/bun). Do **not** ask chmod, DNS, or `gh auth`.
  - **Real host: not in group `docker`:** `/var/run/docker.sock` **exists** (mode `660 root:docker`), `required_permissions: ["all"]` already ran unrestricted, and `id -nG` has **no** `docker` → EACCES is host config, not the sandbox cluster. Ensure may say `sem acesso a /var/run/docker.sock` (or an old build may mis-report `imagem … ausente`). Ask the user to run `sudo usermod -aG docker $USER` and **re-login** (see `host-setup.md` **Docker no jarvis**). Do **not** treat this as “build the image by hand” first.
  - If Auto-review **Ask**/blocks the unrestricted shell (expected for ensure/open/destroy — `~/.cursor/permissions.json` asks, does not auto-allow): retry the **exact same** command via the approval card (`request_smart_mode_approval`). Do **not** ask them to chmod, fix DNS, `gh auth login`, or paste ensure/sandbox in a terminal unless `all` already ran **unrestricted** and still failed for a real host reason.
  - Do **not** stop the prompt / mark coverage·mutation **Blocked** declaring tooling/host broken while only the sandboxed shell failed.
- First day → creates state, `port_base`, `~/git/olie/<id>.code-workspace`, opens Cursor, brings up **compose slim + Vite front**, and registers DNS via Caddy (`lib/host-card-proxy.sh`).
- **api-main worktree branch:** if a local or `origin` branch name already contains the card code (ex. `feature/DOP-1273-…`), ensure checks it out **in the card worktree** (not the shared clone). No matching branch yet → worktree stays on `develop`/HEAD until implementation creates one.
- Browser (slug = código em minúsculas, ex. `dop-1183`):
  - Front: `http://devframe.{slug}.olie.localhost`
  - API: `http://api.{slug}.olie.localhost`
  - Do **not** use bare `devframe.olie.localhost` for a host-card (colide entre cards).
- Later day / re-paste → **resume** the same id (compose up again; do not destroy); worktree checkout runs again on resume; if Cursor already has the card window → **focus** it (do **not** close/reopen — that killed colleague-review chats mid-ensure). Use `open` when you need the SCM close+reopen dance. From inside the card window with stack already up: `WORKVM_HOST_CARD_OPEN_CURSOR=0` on ensure.
- Report `id`, `port_base`, `front_dns` / `api_dns`, and `workspace` in chat.
- Requires clones + `vendor` on the host. If the hook or CLI fails after an unrestricted re-run, stop (prompt-health).
- **olie-e2e ownership:** host-card e2e runs as `HOST_UID`/`HOST_GID` (not `0:0`). If `open`/`destroy` still hits `Permission denied` on `worktree/git` leftovers from an old root/nobody Playwright run, the CLI uses `workvm_host_card_rm_rf` (Docker alpine) — do not sudo; do not ask the user to `chown` by hand.

**Destroy (only when the card is finished):** remove containers/networks for that compose project, generated workspace, and state dir.

```bash
~/git/bin/workvm-host-card destroy --project olie --code '{{ code }}'
```

**After destroy succeeds — stop the project’s main compose** (`COMPOSE_DIR` in `olie/project.conf`, usually `~/git/olie`):

```bash
docker compose -f ~/git/olie/docker-compose.yml down
# equivalent: (cd ~/git/olie && docker compose down)
```

`destroy` only tears down **this card’s** `hc-olie-…` stack. It does **not** stop the project compose from `project.conf` (`olie-api-main`, fronts, …) nor shared `olie-hc-*` (`hc-olie-data`). The agent **must** run the main `docker compose down` on finalize/`finish card` / production-review `done` teardown so those containers do not keep burning RAM. Do **not** `docker compose down` on `olie/sandbox/compose.host-data.yml` / `hc-olie-data` while other Olie cards or sandboxes may still need MySQL/Redis/Mongo. Do **not** stop other cards’ `hc-olie-*` compose projects.

Run destroy when:

1. The card moved to logical `done` ('concluído') after user confirmation (typical: production-review Pass + yes), **after** the move succeeds; or
2. The user sends `finish card` / `finalize card` (see **Chat commands** in `workflow-policy/gates.md`) — **local teardown only**, no board move.

Do **not** destroy at the end of an implementation/correction/colleague-review paste, when closing the chat for the day, or when the card only moves to QA/CR, Validação, or Corrigir.

Child exclusive jobs (mutation/Pest) still use `~/git/bin/workvm-sandbox --project olie` on top of this host card.

## Several cards at once

The board shows one project execution. Several **host cards** can run at the same time; each needs its own `workvm-host-card ensure` id / ports.

The Opbed Job page (`/job`) reads `board_executions` and sends the project-execution requests, one card at a time, for each card's 'Tempo que eu acho'. This chat does not send those requests, does not end an execution, and does not ask for the codes.

The user works every listed card in parallel (one Cursor window / host-card unit per code).

## Temporary E2E CAPTCHA

Playwright stubs `grecaptcha` with a fake token. `api-main` skips `RecaptchaValidate` only when `APP_ENV=testing`. Local `APP_ENV` is `local`, so Google's public **test key pair** via env only:

| Side | Where | Test value |
| --- | --- | --- |
| Secret | `api-main` `.env` → `RECAPTCHA_SECRET` | `6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe` |
| Site key | `olie-fronts/packages/management/.env.development.local` → `VITE_APP_RECAPTCHA_SITE_KEY` | `6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI` |

**Server:** backup prior secret to `~/.config/workvm/api-main.env.recaptcha-backup` (`chmod 600`) if needed; set test secret; `docker exec olie-api-main php artisan config:clear`; smoke `POST /api/management/login/identify` with a fake token → `method: password`. **Browser:** write `.env.development.local` (git exclude); backup prior site key; `docker restart olie-front-management`.

**Forbidden:** stub management API; comment out / delete `RecaptchaValidate` / `getToken()`; edit tracked `.env.development`; commit env overrides. Cursor rule `local-recaptcha-bypass` applies the same steps automatically when login/e2e needs it.
## Payment test cards

A review that charges a card has no safe number unless these are written down. Use only these numbers. Do not use a real card.

| Number | Result |
| --- | --- |
| `4000000000000010` | Success. Order **Pago**, transaction **Capturada**. |
| `4000000000000028` | Failure. Not authorized. |
| `4000000000000036` | Processing, then success. |
| `4000000000000044` | Processing, then failure. |

When the change needs more than one outcome, run each relevant number. A success-only check does not cover an unauthorized charge or a charge that stays in processing.

## Production verification URL

Production review (`production-review` / 'Revisão de Produção') checks the **gui1** frame. Log in at **https://gui1.olie.ai/auth/login** with the accounts in `~/git/olie/prompts/production-review.md` (primary admin, plus the disposable second collaborator when a two-session check is required). Local hosts (`*.olie.localhost`), `https://esolie.olie.ai`, and other frames are not production evidence.

## Olie docs repository — never touch

The clone `~/git/olie/docs` (`olie-ai/docs`, docs.olie.ai / public OpenAPI) is **out of scope** for every agent workflow (implementation, correction, pre-QA, colleague review, production review).

Do not edit, rebase, merge, commit, push, or open/update PRs in that repository. Do not put it on a card’s repository list or correction plan. If a card or review mentions public docs, report that and continue only in company product repos (`api-main`, `olie-fronts`, …). Private Playwright stays in meta-repo `olie/olie-e2e` and must not be cited publicly (**Private E2E suites**). Meta-repo docs under `~/git` (`olie/prompts/`, `HISTORICO.md`, overlay) remain allowed.

If that clone is already mid-rebase or dirty from a mistaken agent pass: abort/restore safely and stop; do not finish the conflict.

## Private E2E suites (olie-e2e — owner only)

The private Playwright suite is **personal host-card tooling**. It is not on the company remotes and other developers do not have those specs. Locav is the exception among EnterScience products: Cypress lives **inside** `locav-front` on the company branch, so Locav may cite its e2e in repos, PRs, and card content.

### Path resolution (write here — avoid permission prompts)

Prompts may still say `~/git/olie/olie-e2e`. **Resolve the writable root** before create/edit:

1. If the open workspace has a folder named **`olie-e2e`**, use **that** folder (host-card: meta worktree under `~/.local/share/workvm/host-cards/olie/<id>/worktree/git/olie/olie-e2e`).
2. Else use `~/git/olie/olie-e2e` only when that path is inside the open workspace.

Never create specs under `~/git/olie/olie-e2e` when that path is **outside** the open workspace folders — Cursor will ask to approve a write outside the workspace. Prefer the in-workspace `olie-e2e` / meta `git` worktree so edits need no extra permission.

For **Olie** (and any product whose Playwright suite lives only under the meta-repo):

- Agents **may** add/run/commit Playwright under the resolved e2e root (commit in the card’s meta worktree) and mention results **only in Cursor chat**.
- Do **not** cite `olie-e2e`, Playwright meta specs, `~/git/olie/olie-e2e/...`, or “e2e coverage added in the meta-repo” in:
  - Olie project/card content (`save-media-tool`, description, form answers, tags notes)
  - Caderno / notebook pages
  - Company repository files (comments, README, changelog)
  - Pull request titles or bodies on `olie-ai/*`
- PR verification text may say the behavior was checked (manual or “verified locally”) without naming the private suite.
- Colleague-review fail notes on the card must describe the missing **product** behavior, not “add a test in olie-e2e”.

## Language

- UI copy, user-facing product content, and card notes are Brazilian Portuguese.
- Commit messages, pull request titles, and pull request bodies are English.
- Do not edit `en.json`. English translations are resolved later. New or changed UI keys go in `pt-br.json` only.

## Formatting

- During implementation, do not run Pint unless the user explicitly asks for it or the task is the pre-QA workflow.
- During pre-QA, run Pint for affected `api-main` PHP changes. If Pint changes files, isolate those formatting-only changes in a dedicated commit; do not create an empty formatting commit.
