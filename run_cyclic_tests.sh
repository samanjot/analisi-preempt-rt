#!/usr/bin/env bash
set -euo pipefail

################################
# Force running as root
################################
if [[ ${EUID:-0} -ne 0 ]]; then
  echo "This script must be run with sudo:"
  echo "  sudo $0 $*"
  exit 1
fi

################################
# Usage
################################
usage() {
  cat <<'EOF'
Usage: run_cyclic_tests.sh [options]

Standard Tests (CPU Timer):
      --baseline                Run baseline cyclictest (default: false)
      --stress-min              Run stress-ng at smin freq (default: false)
      --stress-max              Run stress-ng at smax freq (default: false)
  -t, --timeout <seconds>       Duration for cyclictest (default: 30)
      --smin <freq>             stress-ng --timer-freq for stress-min (default: 100000)
      --smax <freq>             stress-ng --timer-freq for stress-max (default: 1000000)

Memory Interference Tests:
      --mem-baseline            Run baseline membench (linear + random)
      --mem-interf              Run cyclictest with memory interference scan
      --mem-interf-100k         Run cyclictest + mem interf + stress-ng (100k)
      --mem-interf-1M           Run cyclictest + mem interf + stress-ng (1M)
      --interf-cores <N>        Max cores for interference scan (default: nproc-1)
      --membench-cmd <path>     Path to membench tool (default: search PATH)
      --meminterf-cmd <path>    Path to meminterf tool (default: search PATH)

General:
  -n, --name <suffix>           Scenario suffix for output files (default: default)
      --outdir <dir>            Output directory (default: .)
      --hist <max_us>           Enable cyclictest histogram up to max_us (default: 4000)
      --nohist                  Disable histogram output
  -h, --help                    Show this help
EOF
}

################################
# Defaults
################################
# Standard Tests
run_baseline=false
run_stress_min=false
run_stress_max=false

timeout=30
smin=100000
smax=1000000
scenario_name="default"
outdir="."

hist=true
hist_max_us=4000

# Memory Tests
run_mem_baseline=false
run_mem_interf=false
run_mem_interf_100k=false
run_mem_interf_1M=false

# Default to nproc - 1, ensuring at least 1
max_interf_cores=$(($(nproc) - 1))
[[ $max_interf_cores -lt 1 ]] && max_interf_cores=1

membench_cmd="membench"
meminterf_cmd="meminterf"

################################
# Helpers
################################
die() { echo "Error: $*" >&2; exit 1; }

format_label() {
  local freq="$1"
  if (( freq % 1000000 == 0 )); then
    echo "$((freq / 1000000))M"
  elif (( freq % 1000 == 0 )); then
    echo "$((freq / 1000))k"
  else
    echo "$freq"
  fi
}

require_int() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] || die "$2 must be integer"
}

require_ge1() {
  require_int "$1" "$2"
  (( "$1" >= 1 )) || die "$2 must be >= 1"
}

resolve_cmd() {
  local cmd_var="$1"
  local cmd_name="$2"
  if [[ -x "${!cmd_var}" ]]; then
      return 0
  fi
  if command -v "${!cmd_var}" >/dev/null 2>&1; then
      return 0
  else
      die "$cmd_name tool not found: ${!cmd_var}. Please install it or specify path."
  fi
}

################################
# Parse args
################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    # Standard Tests
    -b|--baseline)
      run_baseline=true; shift ;;

    --stress-min)
      run_stress_min=true; shift ;;
      
    --stress-max)
      run_stress_max=true; shift ;;

    -t|--timeout)
      [[ $# -lt 2 ]] && die "Missing value for $1"
      timeout="$2"; require_ge1 "$timeout" "timeout"; shift 2 ;;

    --smin)
      [[ $# -lt 2 ]] && die "Missing value for $1"
      smin="$2"; require_ge1 "$smin" "smin"; shift 2 ;;

    --smax)
      [[ $# -lt 2 ]] && die "Missing value for $1"
      smax="$2"; require_ge1 "$smax" "smax"; shift 2 ;;

    # Memory Tests
    --mem-baseline)
      run_mem_baseline=true; shift ;;
      
    --mem-interf)
      run_mem_interf=true; shift ;;

    --mem-interf-100k)
      run_mem_interf_100k=true; shift ;;

    --mem-interf-1M)
      run_mem_interf_1M=true; shift ;;

    --interf-cores)
      [[ $# -lt 2 ]] && die "Missing value for $1"
      max_interf_cores="$2"; require_ge1 "$max_interf_cores" "interf-cores"; shift 2 ;;

    --membench-cmd)
      [[ $# -lt 2 ]] && die "Missing value for $1"
      membench_cmd="$2"; shift 2 ;;

    --meminterf-cmd)
      [[ $# -lt 2 ]] && die "Missing value for $1"
      meminterf_cmd="$2"; shift 2 ;;

    # General
    -n|--name)
      [[ $# -lt 2 ]] && die "Missing value for $1"
      scenario_name="$2"; shift 2 ;;

    --outdir)
      [[ $# -lt 2 ]] && die "Missing value for $1"
      outdir="$2"; shift 2 ;;

    --hist)
      [[ $# -lt 2 ]] && die "Missing value for $1"
      hist_max_us="$2"; require_ge1 "$hist_max_us" "hist"; shift 2 ;;

    --nohist)
      hist=false; shift ;;

    -h|--help)
      usage; exit 0 ;;

    *)
      echo "Unknown option $1"
      usage
      exit 1 ;;
  esac
done

################################
# Preflight
################################
# Check cyclictest only if we are running any test that uses it
if [[ "$run_baseline" == true || "$run_stress_min" == true || "$run_stress_max" == true || \
      "$run_mem_interf" == true || "$run_mem_interf_100k" == true || "$run_mem_interf_1M" == true ]]; then
    command -v cyclictest >/dev/null 2>&1 || die "cyclictest not found in PATH"
fi

if [[ "$run_stress_min" == true || "$run_stress_max" == true || \
      "$run_mem_interf_100k" == true || "$run_mem_interf_1M" == true ]]; then
    command -v stress-ng  >/dev/null 2>&1 || die "stress-ng not found in PATH"
fi

if [[ "$run_mem_baseline" == true ]]; then
    resolve_cmd membench_cmd "membench"
fi
if [[ "$run_mem_interf" == true || "$run_mem_interf_100k" == true || "$run_mem_interf_1M" == true ]]; then
    resolve_cmd meminterf_cmd "meminterf"
fi

mkdir -p "$outdir"

# Disable RT throttling if memory tests are requested
if [[ "$run_mem_interf" == true || "$run_mem_interf_100k" == true || "$run_mem_interf_1M" == true ]]; then
    echo "Disabling kernel.sched_rt_runtime_us for memory interference tests"
    sysctl -w kernel.sched_rt_runtime_us=-1 >/dev/null
fi

################################
# Cleanup
################################
stress_pid=""
cleanup() {
  if [[ -n "${stress_pid:-}" ]]; then
    kill -- "-$stress_pid" 2>/dev/null || kill "$stress_pid" 2>/dev/null || true
    stress_pid=""
  fi
  # Kill meminterf if running
  killall -9 "$(basename "$meminterf_cmd")" 2>/dev/null || true
}
trap cleanup EXIT

################################
# Runners
################################
run_cyclic() {
  local json="$1"
  local histfile="$2"
  local affinity="${3:-}" # Optional affinity arg

  local cmd=(cyclictest -p 99 -m -i 1000 -D"$timeout" -q)
  
  if [[ -n "$affinity" ]]; then
      cmd+=(-a "$affinity")
  else
      cmd+=(-S) # Default to SMP if no affinity specified
  fi

  cmd+=(--json="$json")
  if [[ "$hist" == true ]]; then
    cmd+=(--histogram="$hist_max_us" --histfile="$histfile")
  fi

  echo "→ ${cmd[*]}"
  "${cmd[@]}"
}

run_with_stress() {
  local freq="$1"
  local json="$2"
  local histfile="$3"
  local stress_timeout=$((timeout + 4))

  echo "→ stress-ng --timer-freq=$freq (timeout=$stress_timeout)"
  setsid stress-ng --timer 0 --timer-freq "$freq" --timer-slack 1 \
                   --timeout "$stress_timeout" \
                   --metrics-brief --times >"$outdir/stress_timer_${freq}_${scenario_name}.log" 2>&1 &
  stress_pid=$!

  sleep 2
  run_cyclic "$json" "$histfile"

  wait "$stress_pid" || true
  stress_pid=""
}

run_mem_baseline() {
    echo "Running baseline membench tests..."
    local linear_file="$outdir/membench_baseline_linear_${scenario_name}.txt"
    local random_file="$outdir/membench_baseline_random_${scenario_name}.txt"
    
    echo "  → Linear: $linear_file"
    "$membench_cmd" > "$linear_file"
    sleep 10s
    
    echo "  → Random: $random_file"
    "$membench_cmd" -r > "$random_file"
    sleep 10s
}

run_interf_scan() {
    local use_stress="$1" # "none", "100k", "1M"
    local suffix="$2"
    
    echo "== Memory Interference Scan [$suffix] =="
    
    for (( cores=1; cores<=max_interf_cores; cores++ )); do
        echo "  [Cores: $cores] Starting interference..."
        
        # Start meminterf on cores 1..cores
        for (( c=1; c<=cores; c++ )); do
             taskset -c $c "$meminterf_cmd" -v --size=156 --iterations=6000 --test=memcpy >/dev/null 2>&1 &
        done
        
        sleep 1
        
        local json="${outdir%/}/cyclic_${suffix}_${cores}cores_${scenario_name}.json"
        local histfile="${outdir%/}/cyclic_${suffix}_${cores}cores_${scenario_name}.hist"
        
        if [[ "$use_stress" == "none" ]]; then
            # Run on core 0
            run_cyclic "$json" "$histfile" "0" 
        else
            # Stress on core 0
            local freq=""
            if [[ "$use_stress" == "100k" ]]; then freq=100000; fi
            if [[ "$use_stress" == "1M" ]]; then freq=1000000; fi
            
            local stress_timeout=$((timeout + 4))
            echo "    + stress-ng core 0 ($freq)"
            setsid stress-ng --timer 1 --taskset 0 --timer-freq "$freq" --timer-slack 0 \
                             --timeout "$stress_timeout" \
                             --metrics-brief --times >/dev/null 2>&1 &
            stress_pid=$!
            
            run_cyclic "$json" "$histfile" "0"
            
            wait "$stress_pid" || true
            stress_pid=""
        fi
        
        echo "  [Cores: $cores] Cleaning up..."
        killall -9 "$(basename "$meminterf_cmd")" 2>/dev/null || true
        wait
    done
}

################################
# Filenames (Standard Tests)
################################
smin_label=$(format_label "$smin")
smax_label=$(format_label "$smax")

baseline_json="${outdir%/}/cyclic_baseline_${scenario_name}.json"
smin_json="${outdir%/}/cyclic_stress_${smin_label}_${scenario_name}.json"
smax_json="${outdir%/}/cyclic_stress_${smax_label}_${scenario_name}.json"

baseline_hist="${outdir%/}/cyclic_baseline_${scenario_name}.hist"
smin_hist="${outdir%/}/cyclic_stress_${smin_label}_${scenario_name}.hist"
smax_hist="${outdir%/}/cyclic_stress_${smax_label}_${scenario_name}.hist"

################################
# Run
################################

# Standard tests
if [[ "$run_baseline" == true ]]; then
    echo "Running Standard Baseline..."
    run_cyclic "$baseline_json" "$baseline_hist"
fi

if [[ "$run_stress_min" == true ]]; then
    run_with_stress "$smin" "$smin_json" "$smin_hist"
fi

if [[ "$run_stress_max" == true ]]; then
    run_with_stress "$smax" "$smax_json" "$smax_hist"
fi

# New Memory Tests
if [[ "$run_mem_baseline" == true ]]; then
    run_mem_baseline
fi

if [[ "$run_mem_interf" == true ]]; then
    run_interf_scan "none" "stress_hesoc"
fi

if [[ "$run_mem_interf_100k" == true ]]; then
    run_interf_scan "100k" "stress_mem_100k"
fi

if [[ "$run_mem_interf_1M" == true ]]; then
    run_interf_scan "1M" "stress_mem_1M"
fi

echo "All tests completed."
