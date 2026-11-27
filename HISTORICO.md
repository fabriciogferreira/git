# Histórico


## Remoção de VMs de programação (tudo no host)

- **problema:** meta-repo ainda versionava Card VM / WorkVM / hooks libvirt / `vm-setup` / virtio / card-agent enquanto a programação já era host-card no jarvis.
- **por que é um problema:** fonte morta; agente e docs apontavam para virsh/guest; atrito e falsa dualidade WorkVM vs host.
- **resolvido como:** apagou bins/units guest (`ensure/drop/open-*-vm`, hooks, card-agent, `vm-setup`, virtio, `backend-vm`, ed25519 guest); sandbox só `container`; docs/rules/README/`host-cards-no-vm.md` = host; CAPTCHA/skills vídeo → `127.0.0.1`; login bootstrap (`project-setup` / `workvm.service` / `project-start`) mantido. Domains libvirt no OS ficam para limpeza manual fora do git.

## implementation.md / correction.md enxutos (Card Spec)

- **problema:** `implementation.md` (~260 linhas) e `correction.md` ainda repetiam policy (CAPTCHA passo a passo, stage/git/media longos) depois do Card Spec e do fatiamento do `workflow-policy`.
- **por que é um problema:** paste de implementação/correção ainda carregava receita mecânica; CAPTCHA canônico apontava para §7 do prompt em vez do módulo host.
- **resolvido como:** prompts ~50 linhas (ensure + dump → plan → code; correction: findings/PR prepare-only + TDD). CAPTCHA completo em `workflow-policy/host.md`; rule `local-recaptcha-bypass`, `colleague-review-core` e `olie-e2e/README` apontam para lá.

## workflow-policy fatiado (módulos)

- **problema:** `olie/prompts/workflow-policy.md` (~70k / 697 linhas) entrava inteiro em quase todo paste.
- **por que é um problema:** custo fixo de tokens; a maior parte das seções não se aplica ao prompt da vez.
- **resolvido como:** índice fino em `workflow-policy.md` + pasta `workflow-policy/{tools,gates,board,host,card-context,evidence}.md`. Prompts Olie citam o módulo; locav/televisão intactos (cópias próprias). Depois: tirar receitas mecânicas (curl move/checklist, walk Caderno/media MCP, git change-set, PR form write) dos módulos — isso é Card Spec / Gap / Coverage / Mutation / Pre-QA.

## Pre-QA mecânico no manager (PR + checklist + move)

- **problema:** `pre-qa.md` pedia ao agente commitlint, `gh pr create`, toggle checklist, forms e move no mesmo paste que UX/docs/evidência.
- **por que é um problema:** tokens e atrito Auto-review no chat; handoff mecânico é orquestração do usuário.
- **resolvido como:** manager **Pre-QA** → `bin/workvm-host-card-pre-qa` + `lib/pre_qa/run.py` (dry-run/apply, `--docs sim|nao`). Prompt enxuto: Phase A julgamento → user Apply → Phase B lê artefato e posta Decisões/Evidência.