# Olie Workflow Policy — Evidence & decisions tables

Load this module only when posting Decisões/Evidência tables to card content.

Index: `~/git/olie/prompts/workflow-policy.md`

## Evidence table on project content

At the **end** of each trigger below, post a short Brazilian Portuguese **evidence table** into the **card content** (project timeline / chat) with MCP **`save-media-tool`** (`project_identifier` = CODE or UUID, `text` = the markdown block). This is human evidence for the board — not a prompt path, not sandbox jargon. On **`pre-qa.md`**, if a **Decisions** table applies for this round, post it **first** (**Deferred decisions** / Decisions table in `workflow-policy/card-context.md`), then this evidence table.

**Destination (only):** card content via `save-media-tool`.

**Never** put the evidence table in:

- the project **description** (`edit-project-tool` / `description`)
- the **Caderno** / notebook (`edit-notebook-page-tool` / forum pages)
- a **PR** title or body

### When to write

| Trigger | When | Heading (exact `###` line) |
| --- | --- | --- |
| Implementation handoff | End of **`pre-qa.md`**, after a successful move to 'QA/CR' (or after the report if the move was blocked — still write what ran) | `### Evidência — Implementation` |
| Correction | End of **`correction.md`** when that paste’s correction work is complete (not the conflict-only first stop). Post again at the end of the following **`pre-qa.md`** that returns the card to 'QA/CR' | `### Evidência — {N}º Correção` |
| Colleague review | End of **`colleague-review.md`** combined outcome on **Pass** or **Corrigir** bounce — **not** while stuck in **reviewer-fix** with open gap/mutation/coverage | `### Evidência — {N}º QA/CR pelo {Nome}` |
| Production review | End of **`production-review.md`** after Pass/Fail/Blocked is reported (before or after the yes/no move) | `### Evidência — {N}º Revisão produção` |

`{N}` = count of existing media texts that already use that heading kind + 1 (1º, 2º, 3º…), unless you are **refreshing the same round** (correction → following pre-qa): then reuse the same `{N}` / same exact `###` line. `{Nome}` = reviewer display name (e.g. Fabrício Ferreira from 'atribuído a' / form). Do **not** invent a round number.

### How to post (card content only)

1. Prefer Card Spec `media.md` (or a light MCP list with `filter: "default"` only if you must count live headings). Count prior evidence headings of the same kind for `{N}`.
2. Call **`save-media-tool`** with the full markdown block (heading + tables). One media message per write.
3. There is no edit-media tool: to refresh the same round (e.g. Correção after pre-qa fills %), **post a new** `save-media-tool` message with the **same exact** `###` heading and the updated tables. Source of truth = the **latest** media whose text starts with that heading. Do not rewrite description or Caderno to “fix” older posts.
4. Do not fold evidence into other notes, PR links blocks, or notebook pages.

### Diff range for mutation / coverage / all-test %

Use the product PR (or card branch) range **`A..B`** where:

- **A** = merge-base with the repo base branch (`develop` / project default).
- **B** = last **non-formatting** commit on the card branch.

**Exclude** the dedicated formatting commit(s) from **B** (Olie: Pint; Locav: PHP CS Fixer; Televisão: Pint and/or dedicated Scribe output). If the tip is only formatting, set **B** to the parent of that commit. State `diff: A..B` (short SHAs) on one line under the heading when back rows include %.

Mutation / coverage % = **changed production / test surface in that diff** (same scope as the mutation/coverage prompts), not the whole repository. Report whether the agreed **~1 percentage-point** progress on that scope was met (`sim` / `não` / `n/a` if no prior baseline).

### Row rules

- Omit the entire **Front** or **Back** section when that surface was not touched in the change set.
- Values: short facts only (`ok`, `falhou`, `n/a`, `não rodado`, percentages). No prompt filenames, no VM/sandbox/ledger words, no private e2e paths.
- **E2E (Olie):** do **not** name `olie-e2e` / Playwright meta. Use e.g. `verificado localmente (ok)` / `criados e ok` / `falhou` / `n/a` — **Private E2E suites** in `workflow-policy/host.md`.
- **UX (Olie Front):** when a UI path was touched, fill the UX rows below (or `n/a` if that check does not apply). Prefer Playwright assertions in the private suite + browser walk on colleague; do **not** use axe / WCAG automated contrast as a gate — the Olie palette may sit below WCAG and still be correct for the team. Judge contrast against the **Olie design system / same screen on develop**, in **light and dark**. Chat scoreboard stays detailed; the card table is the compact public summary.

### UX rows (Olie Front — how to verify)

Omit the whole UX block only when no UI was touched. Otherwise fill each row (`ok` / `falhou` / `n/a` / `não rodado`).

| Row | Meaning | How to catch (no axe) |
| --- | --- | --- |
| **contraste** | Texto legível no caminho do card em tema **claro e escuro**, no padrão Olie (não score WCAG) | Toggle dos dois temas; comparar com design system / `develop`; falha = ilegível ou pior que o padrão do app neste fluxo |
| **feedback** | Request mostra carregando; erro de API aparece para o usuário; sucesso não finje se a API falhou | Atrasar/mockar a API no e2e ou DevTools: spinner/`aria-busy`/botão disabled durante o wait; 4xx/5xx → toast/mensagem; UI não fica em estado de sucesso falso |
| **comportamento** | Atende o pedido do card; overlays fecham ao clicar fora (quando o design manda); controle clicável não está atrás de outro (z-index) | Aceitação = spec/e2e + mídia do card; dropdown/dialog → click no body / Escape; CTA → `elementFromPoint` no centro ou click real que dispara a ação |

Colleague review and Implementation/Correção evidence include these rows when Front applies. Production review: contraste + comportamento on gui1 when UI was in scope; feedback when an API path is exercised in production-safe form.

### JS → TypeScript (Olie fronts — Implementation / Correção)

Olie front packages are mostly JavaScript today. Policy: **migrate gradually**; **new code is TypeScript**; when editing a `.js` / `.jsx` / `.vue` without `lang="ts"`, convert that file in the same change when the blast radius is proportional to the card.

Applies to front repos touched on the card (typically `olie-fronts`, and other front packages when present). **Olie only** — not Locav/Televisão evidence tables.

On **`### Evidência — Implementation`** and **`### Evidência — {N}º Correção`** (when any front JS/TS surface was touched), after the Front checks table, include the two tables below when they have rows. Omit a table entirely when it would be empty. Omit both when no front JS/TS files were added or modified.

1. **Arquivos mexidos mas não convertidos para TypeScript** — every modified file that was already JS (or Vue SFC without `lang="ts"`) and **stayed** JS after the change. One row per path; **motivo** required (Brazilian Portuguese, concrete — e.g. arquivo grande demais para o escopo do card; dependências JS em cascata que forçariam converter N módulos fora do card). Do **not** list files that were converted (`.js` → `.ts` / `lang="ts"`) or that were already TypeScript.
2. **Novos arquivos que nasceram em JavaScript** — every **new** front file added as `.js` / `.jsx` / `.vue` without TypeScript. One row per path; **motivo** required. Default expectation is new files in `.ts` / `.tsx` / `<script setup lang="ts">`; a JS birth needs an explicit reason (e.g. as funções que ele usa ainda são JS e converter a cadeia não compensa neste card).

Converted files and new TypeScript files do **not** need a success table on the card — chat report is enough.

### Options API → Composition API (Olie Vue — Implementation / Correção)

Many Vue SFCs still use Options API (`export default { data, methods, … }`). Policy: **migrate gradually**; **new Vue components use Composition API** (`<script setup>` preferred; Composition without `setup` only when required). When editing an Options-API `.vue`, convert it to Composition in the same change when the blast radius fits the card.

Same scope as JS→TS (**Olie fronts only**). On Implementation / Correção evidence blocks, after the JS→TS tables (if any), include the two tables below when they have rows. Omit a table when empty. Omit both when no `.vue` files were added or modified.

1. **Arquivos Vue mexidos mas não convertidos para Composition API** — every modified `.vue` that was Options API (or hybrid that remained Options-primary) and **stayed** Options after the change. One row per path; **motivo** required (e.g. SFC grande demais para o escopo; mixins/`map*`/legado que forçariam reescrever módulos fora do card). Do **not** list files converted to `<script setup>` / Composition, or that were already Composition.
2. **Novos arquivos Vue que nasceram em Options API** — every **new** `.vue` added with Options API. One row per path; **motivo** required. Default is Composition (`<script setup>`). Options birth needs an explicit reason (rare — e.g. cópia mínima de um padrão Options adjacente que converteria uma árvore inteira fora do card).

A temporary Options + Composition dual-script while migrating a legacy SFC is fine; do **not** put that file in either table if the change moved it toward Composition (`<script setup>` present for the new/changed parts). Converted and new Composition SFCs need no success table on the card.

### Template (Olie)

```markdown
### Evidência — Implementation

**Front**
| check | resultado |
| --- | --- |
| deploy | ok / falhou / n/a |
| e2e | verificado localmente (ok) / falhou / n/a |
| tsc | ok / falhou / n/a |
| lint | ok / falhou / n/a |
| contraste | ok claro+escuro (padrão Olie) / falhou / n/a |
| feedback | loading+erro API ok / falhou / n/a |
| comportamento | aceite+overlay+clicável ok / falhou / n/a |

**Arquivos mexidos mas não convertidos para TypeScript**
| arquivo | motivo |
| --- | --- |
| packages/management/src/…/Foo.vue | arquivo grande demais para o escopo deste card |
| packages/management/src/…/bar.js | converter puxaria a cadeia de helpers JS fora do card |

**Novos arquivos que nasceram em JavaScript**
| arquivo | motivo |
| --- | --- |
| packages/management/src/…/useX.js | as funções que ele usa ainda são JS; converter a cadeia não compensa neste card |

**Arquivos Vue mexidos mas não convertidos para Composition API**
| arquivo | motivo |
| --- | --- |
| packages/management/src/…/LegacyForm.vue | SFC grande com mixins; converter estoura o escopo do card |

**Novos arquivos Vue que nasceram em Options API**
| arquivo | motivo |
| --- | --- |
| packages/management/src/…/CopyPattern.vue | cópia mínima de irmão Options; converter a árvore não compensa neste card |

**Back**
diff: abc1234..def5678 (sem commit Pint)
| check | resultado |
| --- | --- |
| pint | ok / n/a |
| phpstan | ok / falhou / n/a |
| mutation | X% no diff; +Y pp; meta 1 pp: sim/não/n/a |
| coverage | X% no diff; +Y pp; meta 1 pp: sim/não/n/a |
| all test | X% (ou N passed / M total) |
```

Colleague / Correção / Revisão produção use the same Front/Back tables under their heading (production review may be mostly Front + production smoke; use `n/a` where a check does not apply). Correção also includes the JS→TS and Options→Composition tables when front Vue/JS/TS was touched. Colleague and production review omit those migration tables unless the reviewer themselves changed front files in that paste (rare — usually omit).
