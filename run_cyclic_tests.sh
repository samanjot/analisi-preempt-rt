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
  -b, --baseline <true|false>   Run baseline test (default: true)
  -t, --timeout <seconds>       Duration for cyclictest (default: 30)
      --smin <freq>             stress-ng --timer-freq for test 2 (default: 100000)
      --smax <freq>             stress-ng --timer-freq for test 3 (default: 1000000)
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
baseline=true
timeout=30
smin=100000
smax=1000000
scenario_name="default"
outdir="."

hist=true
hist_max_us=4000

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

################################
# Parse args
################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--baseline)
      [[ $# -lt 2 ]] && die "Missing value for $1"
      [[ "$2" == true || "$2" == false ]] || die "baseline must be true|false"
      baseline="$2"; shift 2 ;;

    -t|--timeout)
      [[ $# -lt 2 ]] && die "Missing value for $1"
      timeout="$2"; require_ge1 "$timeout" "timeout"; shift 2 ;;

    --smin)
      [[ $# -lt 2 ]] && die "Missing value for $1"
      smin="$2"; require_ge1 "$smin" "smin"; shift 2 ;;

    --smax)
      [[ $# -lt 2 ]] && die "Missing value for $1"
      smax="$2"; require_ge1 "$smax" "smax"; shift 2 ;;

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
command -v cyclictest >/dev/null 2>&1 || die "cyclictest not found in PATH"
command -v stress-ng  >/dev/null 2>&1 || die "stress-ng not found in PATH"
mkdir -p "$outdir"

################################
# Cleanup
################################
stress_pid=""
cleanup() {
  if [[ -n "${stress_pid:-}" ]]; then
    # Best-effort: kill process group (covers any children), fallback to direct PID.
    kill -- "-$stress_pid" 2>/dev/null || kill "$stress_pid" 2>/dev/null || true
    stress_pid=""
  fi
}
trap cleanup EXIT

################################
# Runners
################################
run_cyclic() {
  local json="$1"
  local histfile="$2"

  echo "→ cyclictest --json=$json (D=$timeout)"
  if [[ "$hist" == true ]]; then
    cyclictest -S -p 99 -m -i 1000 -D"$timeout" -q \
      --json="$json" \
      --histogram="$hist_max_us" --histfile="$histfile"
  else
    cyclictest -S -p 99 -m -i 1000 -D"$timeout" -q --json="$json"
  fi
}

run_with_stress() {
  local freq="$1"
  local json="$2"
  local histfile="$3"
  local stress_timeout=$((timeout + 4))

  echo "→ stress-ng --timer-freq=$freq (timeout=$stress_timeout)"
  # Start stress-ng in a new process group (setsid) so cleanup can kill all its children.
  setsid stress-ng --timer 0 --timer-freq "$freq" --timer-slack 0 \
                   --timeout "$stress_timeout" --metrics-brief --times \
                   >/dev/null 2>&1 &
  stress_pid=$!

  sleep 2
  run_cyclic "$json" "$histfile"

  wait "$stress_pid" || true
  stress_pid=""
}

################################
# Filenames
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
[[ "$baseline" == true ]] && run_cyclic "$baseline_json" "$baseline_hist"
run_with_stress "$smin" "$smin_json" "$smin_hist"
run_with_stress "$smax" "$smax_json" "$smax_hist"

echo "All tests completed."
echo "Outputs:"
[[ "$baseline" == true ]] && echo "  $baseline_json" && [[ "$hist" == true ]] && echo "  $baseline_hist"
echo "  $smin_json"
[[ "$hist" == true ]] && echo "  $smin_hist"
echo "  $smax_json"
[[ "$hist" == true ]] && echo "  $smax_hist"
