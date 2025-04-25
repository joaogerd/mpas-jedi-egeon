#!/usr/bin/env bash
#SBATCH --job-name=mpas_build
#SBATCH --partition=PESQ1          # GPU/CPU partition – adjust as needed
#SBATCH --nodes=1                  # build is not MPI-distributed; 1 node is enough
#SBATCH --time=02:00:00            # wall-time limit (hh:mm:ss)
#SBATCH --exclusive                # reserve full node to avoid I/O contention
#SBATCH --output=logs/build_%j.out # stdout log (jobid in name)
#SBATCH --error=logs/build_%j.err  # stderr log

###############################################################################
# build_job.slurm – MPAS-JEDI compilation job
# -----------------------------------------------------------------------------
# Maintainer : João Gerd Zell de Mattos <joao.gerd@inpe.br>
# Created    : 2025-04-?? (original version)
# Last update: 2025-04-24
#
# PURPOSE
# =======
# Compile the **mpas-bundle** source tree previously configured by CMake in
# <BUILD_DIR>. It relies on a pre-activated Spack-Stack environment that
# provides all dependencies (MPI, NetCDF, etc.). The heavy lifting is done
# with `make -j <num_cores>`; CMake is (re)invoked automatically only if no
# Makefile is present.
#
# USAGE (invoked via sbatch by submit_jobs.sh)
#   sbatch build_job.slurm <BUILD_DIR> <SPACK_DIR> [COMPILER] [PRECISION]
#
# Positional args
#   BUILD_DIR  – directory where CMake has generated the build tree
#   SPACK_DIR  – root of the Spack-Stack environment (contains start_spack_bundle.sh)
#   COMPILER   – toolchain label (gnu|intel|nvhpc …). Default: gnu
#   PRECISION  – "ON" (double) or "OFF" (single). Default: ON
#
# OUTPUT
# ------
# * Compiled binaries & libraries under <BUILD_DIR>
# * Logs
#     logs/build_<jobid>.out – combined stdout
#     logs/build_<jobid>.err – combined stderr
#     <BUILD_DIR>/logs/<date>/make_<jobid>.log – raw make output
#     <BUILD_DIR>/logs/<date>/cmake_<jobid>.log – (re)configuration output if triggered
#
# EXIT CODES
# ----------
#  0  success
#  1  missing dependencies or user error
#  2  build failure
###############################################################################

set -Eeuo pipefail

# ---------------- helper -----------------------------------------------------
log() { printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
die() { printf '[%(%F %T)T] [ERROR] %s\n' -1 "$*" >&2; exit 1; }
trap 'log "ERROR: line $LINENO – exiting."; exit 2' ERR

# ---------------- args -------------------------------------------------------
BUILD_DIR="${1:?<BUILD_DIR> missing}"
SPACK_DIR="${2:?<SPACK_DIR> missing}"
COMPILER="${3:-gnu}"
PRECISION="${4:-ON}"

[[ -d "$BUILD_DIR" ]] || die "BUILD_DIR not found: $BUILD_DIR"
[[ -d "$SPACK_DIR" ]] || die "SPACK_DIR not found: $SPACK_DIR"

# ---------------- environment ------------------------------------------------
SECONDS=0
log "Job started on node $(hostname) at $(date '+%F %T')"
log "BUILD_DIR   = $BUILD_DIR"
log "SPACK_DIR   = $SPACK_DIR"
log "COMPILER    = $COMPILER"
log "PRECISION   = $PRECISION"

log "Activating Spack ..."
source "$SPACK_DIR/start_spack_bundle.sh"

# Logs directory inside build tree
TODAY=$(date +%F)
LOG_DIR="$BUILD_DIR/logs/$TODAY"
mkdir -p "$LOG_DIR"
JOB_ID="${SLURM_JOB_ID:-manual}"

# ---------------- (re)configure if needed -----------------------------------
cd "$BUILD_DIR"
if [[ ! -f Makefile ]]; then
  log "No Makefile found – running CMake reconfiguration."
  cmake .. \
    -DMPAS_DOUBLE_PRECISION="$PRECISION" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    2>&1 | tee "$LOG_DIR/cmake_${JOB_ID}.log"
else
  log "Makefile present – skipping CMake."
fi

# ---------------- compile ----------------------------------------------------
NUM_CORES=$(nproc)
log "Compiling with make -j$NUM_CORES …"
if ! make -j"$NUM_CORES" 2>&1 | tee "$LOG_DIR/make_${JOB_ID}.log"; then
  die "Compilation failed – check $LOG_DIR/make_${JOB_ID}.log"
fi
log "Compilation finished successfully."

# ---------------- epilogue ---------------------------------------------------
DUR=$SECONDS
log "Total elapsed: $((DUR/60)) min $((DUR%60)) s"
log "Logs saved under: $LOG_DIR"

