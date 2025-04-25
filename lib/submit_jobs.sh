#!/usr/bin/env bash
###############################################################################
# submit_jobs.sh
#
# Unified launcher for **MPAS‑JEDI** build & test workflows on Egeon
# -----------------------------------------------------------------------------
# Maintainer : João Gerd Zell de Mattos <joao.gerd@inpe.br>
# Created    : 2025‑04‑?? (original version)
# Last update: 2025-04-24
#
# PURPOSE
# =======
# Build the mpas‑bundle, then run its ctest suite.
# Works in two modes:
#   • **slurm** (default) – submit build & test as separate SLURM jobs.
#   • **local**           – compile on the login node (lib/build_local.sh) and
#                           run `ctest` in‑place.
#
# USAGE
# -----
#   submit_jobs.sh -s <SCRIPT_DIR> -b <BUILD_DIR> -e <SPACK_DIR> \
#                  [-c <compiler>] [-p <ON|OFF>] [-m <slurm|local>] [-h]
#
# Required
#   -s SCRIPT_DIR   Directory containing this helper and subdirs (jobs/, lib/)
#   -b BUILD_DIR    Build directory prepared by build_and_test.sh
#   -e SPACK_DIR    Root of the activated Spack-Stack environment
#
# Optional
#   -c COMPILER     Toolchain label (default: gnu)
#   -p PRECISION    "ON" (double) | "OFF" (single); default: ON
#   -m MODE         "slurm" or "local" (default: slurm)
#   -h              Show this help and exit
#
# REQUIREMENTS
# ------------
# * SLURM ≥ 20.11 with sacct for queue inspection (slurm mode)
# * jobs/build_job.slurm & jobs/ctest_job.slurm present (slurm mode)
# * lib/build_local.sh present & executable (local mode)
#
# CHANGELOG
# ---------
# 2025‑04‑24 – switched to getopts parsing and added detailed usage().
# 2025‑04‑24 – local mode now runs ctest automatically after build.
# 2025‑04‑23 – initial dual‑mode implementation with robust validation.
#
# EXIT CODES
# ----------
#  0  success
#  1  missing dependencies or user error
#  2  unexpected runtime failure
###############################################################################

set -Eeuo pipefail

# ------------ helper ---------------------------------------------------------
usage() {
  awk '
    /^# USAGE/ { in_block=1 }
    /^# REQUIREMENTS/ { exit }
    in_block && /^#/ { sub(/^# ?/, ""); print }
  ' "$0"
  exit 1
}

log() { printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
die() { printf '[%(%F %T)T] [ERROR] %s\n' -1 "$*" >&2; exit 1; }
trap 'log "ERROR: line $LINENO – exiting."; exit 2' ERR

# ------------ defaults -------------------------------------------------------
COMPILER=gnu
PRECISION=ON
MODE=slurm

# ------------ getopts parsing ------------------------------------------------
while getopts ":s:b:e:c:p:m:h" opt; do
  case "$opt" in
    s) SCRIPT_DIR="$OPTARG" ;;
    b) BUILD_DIR="$OPTARG"  ;;
    e) SPACK_DIR="$OPTARG"  ;;
    c) COMPILER="$OPTARG"   ;;
    p) PRECISION="$OPTARG"  ;;
    m) MODE="$OPTARG"       ;;
    h|*) usage ;;
  esac
done

# ------------ required argument checks ----------------------------------------
[[ -z "${SCRIPT_DIR:-}" || -z "${BUILD_DIR:-}" || -z "${SPACK_DIR:-}" ]] && usage

case "$MODE" in
  slurm|local) : ;;
  *) die "Invalid MODE '$MODE'. Use slurm or local." ;;
esac

[[ -d "$SCRIPT_DIR" ]] || die "SCRIPT_DIR not found: $SCRIPT_DIR"
[[ -d "$BUILD_DIR" ]]  || die "BUILD_DIR not found:  $BUILD_DIR"
[[ -d "$SPACK_DIR" ]]  || die "SPACK_DIR not found:  $SPACK_DIR"

# ------------ LOCAL MODE -----------------------------------------------------
if [[ "$MODE" == "local" ]]; then
  [[ -x "$SCRIPT_DIR/lib/build_local.sh" ]] || die "build_local.sh not executable."
  log "[LOCAL] Building via build_local.sh …"
  "$SCRIPT_DIR/lib/build_local.sh" "$BUILD_DIR" "$SPACK_DIR" "$COMPILER" "$PRECISION"
  log "[LOCAL] Build done. Running ctest …"
  (
    cd "$BUILD_DIR"
    ctest --output-on-failure 2>&1 | tee "$BUILD_DIR/ctest_local.log"
  )
  log "[LOCAL] ctest finished. Log: $BUILD_DIR/ctest_local.log"
  exit 0
fi

# ------------ SLURM MODE -----------------------------------------------------
[[ -d "$SCRIPT_DIR/jobs" ]] || die "jobs/ directory missing in $SCRIPT_DIR"
mkdir -p "$BUILD_DIR/logs" || true

log "[SLURM] Submitting build_job.slurm …"
BUILD_JOB_ID=$(sbatch --parsable "$SCRIPT_DIR/jobs/build_job.slurm" \
                            "$BUILD_DIR" "$SPACK_DIR" "$COMPILER" "$PRECISION")
[[ -n "$BUILD_JOB_ID" ]] || die "sbatch returned empty job ID."
log "[SLURM] BUILD job id = $BUILD_JOB_ID"

sleep 3
STATE=$(sacct -j "$BUILD_JOB_ID" --format=State%20 --noheader | head -n1 | awk '{print $1}')
[[ -z "$STATE" ]] && die "BUILD job $BUILD_JOB_ID not visible via sacct."
[[ "$STATE" == FAILED* || "$STATE" == CANCELLED* ]] && die "BUILD job already $STATE"

log "[SLURM] Submitting ctest_job.slurm (afterok:$BUILD_JOB_ID) …"
CTEST_JOB_ID=$(sbatch --dependency=afterok:$BUILD_JOB_ID \
                          "$SCRIPT_DIR/jobs/ctest_job.slurm" "$BUILD_DIR" "$SPACK_DIR")
[[ -n "$CTEST_JOB_ID" ]] || die "Failed to submit ctest job."
log "[SLURM] CTEST job id = $CTEST_JOB_ID (depends on build)"
log "[SLURM] Track jobs with: squeue -j $BUILD_JOB_ID,$CTEST_JOB_ID"

