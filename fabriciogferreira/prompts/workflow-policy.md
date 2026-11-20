# Workflow policy (fabriciogferreira)

Personal WorkVM rules for the fabriciogferreira portfolio. English for prompt bodies.

fabriciogferreira has **no cards**, **no colleague review**, and **no pull requests**. Work on `main`. Production is Vercel (`fabriciogferreira.vercel.app`) — push to `main` typically triggers deploy.

## Feature context

Prompts take `{{ feature }}`: a short description of what to build, fix, or verify. There is no card code or Olie funnel.

## Repos

| Clone | Role |
| --- | --- |
| `~/git/fabriciogferreira/fabriciogferreira` | Next.js portfolio (`npm run dev` / `lint` / `build`) |

## Tool preference

Shell with `required_permissions: ["all"]` for Docker / `workvm-sandbox`. Prefer conventions in the clone’s README / `package.json`.

## Sandbox

Exclusive lint/build drain may use:

```bash
~/git/bin/workvm-sandbox --project fabriciogferreira …
```

Day-to-day `npm run dev` / `lint` on the local compose `frontend` or the host-card frontend.

## Mutation

No Pest/Infection. `mutation-testing.md` is a skip → `pre-deploy.md`.

## Chat commands

| Command | Meaning |
| --- | --- |
| `next prompt` | Open and run the next recommended prompt file. |
| `try again` | Retry the current prompt / last failed check. |
| `to correct` | After production review **Fail**: fix, then `pre-deploy`. |
| `resolva` / `documente` / `resolva permanentemente` | Stop-on-broken-tooling (meta-repo rule). |

## Flow (default)

1. `implementation.md` → build `{{ feature }}`
2. Optional coverage/lint drain in sandbox; mutation is skip
3. `pre-deploy.md` → `npm run lint` + `npm run build` → **commit and push `main`**
4. `production-review.md` → verify Vercel
5. On fail → `correction.md` → `pre-deploy.md` again
