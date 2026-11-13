#!/bin/env bash
# Isolate host cgroups to HOST_ALLOWED while a guest runs; restore ALL_CPUS on release.
# Problem: wiki hardcodes AllowedCPUs for a 12-thread box; this host (and the next) differ.
#
# Computes the plan at runtime (same lib as cpu-pin-plan) unless
# /etc/libvirt/hooks/cpu-pin.env exists (from: cpu-pin-plan --write).
#
# Ops: prepare → shrink host; release → give all CPUs back.
# Optional: only for one guest — set PIN_GUEST_NAME=win11 in cpu-pin.env

OBJECT=$1
OPERATION=$2

case $OPERATION in
  prepare|release) ;;
  *) exit 0 ;;
esac

LIB=${CPU_PIN_LIB:-/usr/local/lib/workvm/cpu-pin-lib.sh}
ENVF=${CPU_PIN_ENV:-/etc/libvirt/hooks/cpu-pin.env}

if [[ -r $ENVF ]]; then
  # shellcheck disable=SC1090
  source "$ENVF"
fi

if [[ -n ${PIN_GUEST_NAME:-} && $OBJECT != "$PIN_GUEST_NAME" ]]; then
  exit 0
fi

if [[ -z ${HOST_ALLOWED:-} || -z ${ALL_CPUS:-} ]]; then
  if [[ ! -r $LIB ]]; then
    echo "cpu-pinning: missing $LIB and incomplete $ENVF" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$LIB"
  cpu_plan
fi

set_allowed() {
  local spec=$1
  systemctl set-property --runtime -- system.slice "AllowedCPUs=$spec"
  systemctl set-property --runtime -- user.slice "AllowedCPUs=$spec"
  systemctl set-property --runtime -- init.scope "AllowedCPUs=$spec"
}

case $OPERATION in
  prepare)
    set_allowed "$HOST_ALLOWED"
    ;;
  release)
    set_allowed "$ALL_CPUS"
    ;;
esac

exit 0
