# Shared CPU pin helpers for host-files (source from plan + libvirt hook).
# Problem: wiki examples hardcode 0-11; a new PC needs topology rediscovered.

# Expand "0-3,8,10-11" → space-separated list
cpu_expand() {
  local spec=$1 out=() part a b i
  IFS=',' read -ra parts <<<"$spec"
  for part in "${parts[@]}"; do
    if [[ $part == *-* ]]; then
      a=${part%-*}; b=${part#*-}
      for ((i = a; i <= b; i++)); do out+=("$i"); done
    else
      out+=("$part")
    fi
  done
  printf '%s\n' "${out[@]}"
}

# Collapse sorted unique ints → compact cpuset (0-3,8,10-11)
cpu_collapse() {
  local -a c=()
  mapfile -t c < <(printf '%s\n' "$@" | sort -n | uniq)
  ((${#c[@]})) || return 0
  local start=${c[0]} prev=${c[0]} out=() i
  for ((i = 1; i < ${#c[@]}; i++)); do
    if ((c[i] == prev + 1)); then
      prev=${c[i]}
      continue
    fi
    if ((start == prev)); then out+=("$start"); else out+=("${start}-${prev}"); fi
    start=${c[i]}; prev=${c[i]}
  done
  if ((start == prev)); then out+=("$start"); else out+=("${start}-${prev}"); fi
  local IFS=,
  echo "${out[*]}"
}

# Online CPU ids
cpu_all_list() {
  cpu_expand "$(cat /sys/devices/system/cpu/online)"
}

# P-cores / E-cores when hybrid sysfs exists; else all = "P"
cpu_p_list() {
  if [[ -r /sys/devices/cpu_core/cpus ]]; then
    cpu_expand "$(cat /sys/devices/cpu_core/cpus)"
  else
    cpu_all_list
  fi
}

cpu_e_list() {
  if [[ -r /sys/devices/cpu_atom/cpus ]]; then
    cpu_expand "$(cat /sys/devices/cpu_atom/cpus)"
  fi
}

# Unique physical core ids for a list of CPU ids (HT siblings share core_id)
cpu_core_id() {
  cat "/sys/devices/system/cpu/cpu$1/topology/core_id"
}

# Threads belonging to the same physical core as CPU $1
cpu_siblings_of() {
  local cpu=$1 list
  list=$(cat "/sys/devices/system/cpu/cpu${cpu}/topology/thread_siblings_list")
  cpu_expand "$list"
}

# Pick first N distinct P-cores (by core_id order of first thread); emit all their threads
# Args: N
cpu_first_n_p_cores_threads() {
  local n=$1
  local -a p=() picked_cores=() out=()
  mapfile -t p < <(cpu_p_list)
  local cpu core
  for cpu in "${p[@]}"; do
    core=$(cpu_core_id "$cpu")
    local seen=0 c
    for c in "${picked_cores[@]+"${picked_cores[@]}"}"; do
      [[ $c == "$core" ]] && { seen=1; break; }
    done
    ((seen)) && continue
    picked_cores+=("$core")
    mapfile -t -O "${#out[@]}" out < <(cpu_siblings_of "$cpu")
    ((${#picked_cores[@]} >= n)) && break
  done
  printf '%s\n' "${out[@]}"
}

# Guest = P threads not in host set; E stay on host by default
# Env: HOST_P_CORES (default 2) — physical P-cores kept for the host while the guest runs
cpu_plan() {
  local host_p_cores=${HOST_P_CORES:-2}
  local -a all=() p=() e=() host=() guest=() host_p=()
  mapfile -t all < <(cpu_all_list)
  mapfile -t p < <(cpu_p_list)
  mapfile -t e < <(cpu_e_list)
  mapfile -t host_p < <(cpu_first_n_p_cores_threads "$host_p_cores")

  local cpu
  for cpu in "${host_p[@]}"; do host+=("$cpu"); done
  for cpu in "${e[@]+"${e[@]}"}"; do host+=("$cpu"); done

  for cpu in "${p[@]}"; do
    local keep=0 h
    for h in "${host_p[@]}"; do
      [[ $h == "$cpu" ]] && { keep=1; break; }
    done
    ((keep)) || guest+=("$cpu")
  done

  HOST_ALLOWED=$(cpu_collapse "${host[@]}")
  GUEST_CPUS=$(cpu_collapse "${guest[@]}")
  ALL_CPUS=$(cpu_collapse "${all[@]}")
  HOST_P_THREADS=$(cpu_collapse "${host_p[@]}")
  E_CPUS=$(cpu_collapse "${e[@]+"${e[@]}"}")
  P_CPUS=$(cpu_collapse "${p[@]}")
  NPROC=${#all[@]}
  GUEST_N=${#guest[@]}
}
