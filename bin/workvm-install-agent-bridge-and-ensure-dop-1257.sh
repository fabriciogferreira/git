#!/usr/bin/env bash
# One-shot (unrestricted shell): promote durable host-card sandbox fixes from the
# card meta worktree into ~/git + ~/.cursor, enable the agent bridge, ensure DOP-1257.
# Problema: o chat do agente não consegue gravar ~/git nem docker.sock no sandbox.
set -euo pipefail

WT="${WORKVM_CARD_META_WT:-/home/fabricio/.local/share/workvm/host-cards/olie/olie-dop-1257/worktree/git}"
LIVE="${GIT_ROOT:-$HOME/git}"

echo "==> Promote from $WT → $LIVE"
install -m 0755 "$WT/bin/workvm-host-card-agent-bridge" "$LIVE/bin/workvm-host-card-agent-bridge"
install -m 0755 "$WT/bin/workvm-host-card-agent-ensure" "$LIVE/bin/workvm-host-card-agent-ensure"
install -m 0755 "$WT/bin/workvm-host-card" "$LIVE/bin/workvm-host-card"
install -m 0644 "$WT/lib/host-card.sh" "$LIVE/lib/host-card.sh"
install -m 0644 "$WT/systemd/workvm-host-card-agent-bridge.service" "$LIVE/systemd/workvm-host-card-agent-bridge.service"
install -m 0600 "$WT/.cursor/permissions.json" "$LIVE/.cursor/permissions.json"
install -m 0600 "$WT/.cursor/permissions.json" "${HOME}/.cursor/permissions.json"
# Keep HISTORICO / workflow / rules in sync for the live meta clone when writable.
cp -a "$WT/HISTORICO.md" "$LIVE/HISTORICO.md"
cp -a "$WT/olie/prompts/workflow-policy.md" "$LIVE/olie/prompts/workflow-policy.md"
cp -a "$WT/.cursor/rules/stop-on-broken-tooling.mdc" "$LIVE/.cursor/rules/stop-on-broken-tooling.mdc"
cp -a "$WT/.cursor/rules/layout.mdc" "$LIVE/.cursor/rules/layout.mdc"

echo "==> Install agent bridge"
"$LIVE/bin/workvm-host-card" install-agent-bridge

echo "==> Ensure DOP-1257"
WORKVM_HOST_CARD_OPEN_CURSOR=0 "$LIVE/bin/workvm-host-card" ensure --project olie --code 'DOP-1257'
echo "==> Probe docker + card ports"
ls -la /var/run/docker.sock
docker ps --format '{{.Names}} {{.Status}}' | head -30
curl -sS -m 3 -o /dev/null -w 'api:%{http_code}\n' "http://127.0.0.1:29300/" || true
curl -sS -m 3 -o /dev/null -w 'front:%{http_code}\n' "http://127.0.0.1:29301/" || true
echo INSTALL_ENSURE_OK
