#!/usr/bin/env bash
#SBATCH --job-name=mpas_ctest
#SBATCH --partition=PESQ1          # same partition as build
#SBATCH --nodes=1
#SBATCH --ntasks=32                # parallel test threads
#SBATCH --time=01:00:00

###############################################################################
# ctest_job.slurm – run MPAS-JEDI unit/integration tests
# -----------------------------------------------------------------------------
# Maintainer : João Gerd Zell de Mattos <joao.gerd@inpe.br>
# Created    : 2025-04-?? (original version)
# Last update: 2025-04-24
#
# PURPOSE
# =======
# Execute `ctest` inside an already compiled build tree.
# Called by submit_jobs.sh with dependency `afterok:<build_job_id>`.
#
# USAGE (invoked via sbatch)
#   sbatch ctest_job.slurm <BUILD_DIR> <SPACK_DIR>
#
# Positional args
#   BUILD_DIR  – directory containing compiled mpas-bundle
#   SPACK_DIR  – root of the Spack-Stack environment (contains start_spack_bundle.sh)
#
# OUTPUT
# ------
# * Logs
#     logs/ctest_<jobid>.out – combined stdout
#     logs/ctest_<jobid>.err – combined stderr
#     <BUILD_DIR>/logs/<date>/ctest_<jobid>.log – raw test output
#
# EXIT CODES
# ----------
#  0  success
#  1  missing dependencies or user error
#  2  unexpected runtime failure
###############################################################################

set -Eeuo pipefail

# ---------------- helper -----------------------------------------------------
log() { printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
die() { printf '[%(%F %T)T] [ERROR] %s\n' -1 "$*" >&2; exit 1; }
trap 'log "ERROR: line $LINENO – exiting."; exit 2' ERR

# ---------------- args -------------------------------------------------------
BUILD_DIR="${1:?BUILD_DIR missing}"
SPACK_DIR="${2:?SPACK_DIR missing}"

[[ -d "$BUILD_DIR" ]] || die "BUILD_DIR not found: $BUILD_DIR"
[[ -d "$SPACK_DIR" ]] || die "SPACK_DIR not found: $SPACK_DIR"

# Prevent accidental propagation of this script's positional parameters.
set --

# ---------------- environment ------------------------------------------------
SECONDS=0
log "CTest job started on node $(hostname) at $(date '+%F %T')"
log "BUILD_DIR = $BUILD_DIR"

source "$SPACK_DIR/start_spack_bundle.sh"

TODAY=$(date +%F)
LOG_DIR="$BUILD_DIR/logs/$TODAY"
mkdir -p "$LOG_DIR"
JOB_ID="${SLURM_JOB_ID:-manual}"

# ---------------- run tests --------------------------------------------------
cd "$BUILD_DIR"
THREADS=$(nproc)
log "Running ctest with $THREADS parallel threads …"
if ! ctest --output-on-failure -j"$THREADS" 2>&1 | tee "$LOG_DIR/ctest_${JOB_ID}.log"; then
  die "CTest returned errors – check log."
fi

# ---------------- epilogue ---------------------------------------------------
DUR=$SECONDS
log "CTest finished successfully in $((DUR/60)) min $((DUR%60)) s"
log "Log saved at: $LOG_DIR/ctest_${JOB_ID}.log"

