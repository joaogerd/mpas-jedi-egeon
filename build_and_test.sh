#!/usr/bin/env bash
###############################################################################
# build_and_test.sh
#
# MPAS‑JEDI automatic build & test driver – Egeon cluster
#
# Maintainer : João Gerd Zell de Mattos <joao.gerd@inpe.br>
# Created    : 2025‑04‑?? (original version)
# Last update: 2025-04-23
#
# PURPOSE
# =======
# This script orchestrates the *entire* build & validation workflow of the
# JCSDA **mpas‑bundle** on the Egeon SLURM cluster.  It takes care of
#  1. selecting an *offline* CMakeLists.txt (kept under `cmake_versions/`)
#  2. setting up a pre‑configured **Spack‑Stack** environment
#  3. configuring the bundle with *cmake* (REMOTE fetch disabled)
#  4. either
#     • launching parallel compilation & ctest through two SLURM jobs, **or**
#     • running them locally (mainly for debug on login nodes)
#
# USAGE
# -----
#   ./build_and_test.sh [-v <VERSION>] [-m <MODE>] [-p <ON|OFF>] [--no-cmake] [-h]
#
# Options
#   -v VERSION   mpas-bundle release tag or branch (default: 3.0.0)
#   -m MODE      'local' (default) or 'slurm'
#   -p PRECISION Build with double precision (ON) or single (OFF). Default: ON
#   --no-cmake   Skip the cmake configuration step
#   -h           show this help and exit
#
# Examples
#   # Build v3.0.1 with SLURM
#   ./build_and_test.sh -v 3.0.1 -m slurm
#
#   # Debug build locally with single precision
#   ./build_and_test.sh -p OFF
#
# REQUIREMENTS
# ------------
#  * Spack‑Stack ≥ 1.7.0 installed at /mnt/beegfs/das.group/spack-envs
#  * Valid mpas-bundle CMakeLists under cmake_versions/
#  * submit_jobs.sh helper under lib/
#  * SLURM (sbatch/squeue) for distributed compilation + tests
#
# CHANGELOG
# ---------
# - 2025-04-24: added die() function, --no-cmake option, and unified logging format.
# - 2025-04-23: full refactor, getopt parsing, robust logging, pipefail,
#               JOBSTAMP instead of undefined JOBID, Markdown header.
#
# EXIT CODES
# ----------
#  0  success
#  1  missing dependencies or user error
#  2  unexpected runtime failure
###############################################################################

set -Eeuo pipefail

# -------- helper functions ---------------------------------------------------
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
trap 'log "[ERROR] line $LINENO – exiting."; exit 2' ERR

# --- host sanity-check (only egeon-login is allowed) -------------------------
LOGIN_HOST="egeon-login.cptec.inpe.br"
CUR_HOST=$(hostname)

if [[ "$CUR_HOST" != "$LOGIN_HOST" ]]; then
  die " This script must be run on $LOGIN_HOST (current: $CUR_HOST)."
fi

# ------------ defaults -------------------------------------------------------
VERSION='3.0.0'
MODE='local'
PRECISION='ON'
RUN_CMAKE=true

# -------- option parsing -----------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERSION="$2"; shift 2 ;;
    -m) MODE="$2"; shift 2 ;;
    -p) PRECISION="$2"; shift 2 ;;
    --no-cmake) RUN_CMAKE=false; shift ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

if [[ "$MODE" != "slurm" && "$MODE" != "local" ]]; then
  die "Invalid mode: '$MODE'. Use 'slurm' or 'local'."
fi

# Prevent accidental propagation of this script's positional parameters.
set --

# -------- constants & paths --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPACK_DIR="/mnt/beegfs/das.group/spack-envs/mpas-bundle"
CMAKE_FILE="$SCRIPT_DIR/cmake_versions/CMakeLists_${VERSION}.txt"

if [[ ! -f "$CMAKE_FILE" ]]; then
  die "CMakeLists for version '$VERSION' not found: $CMAKE_FILE\nHint: did you run sync_cmakelists.sh?"
fi

JOBSTAMP="$(date +'%Y%m%dT%H%M%S')"
SNAPSHOT_DATE="$(date +'%Y-%m-%d')"
BASE_DIR="$SCRIPT_DIR/mpas-bundle-${VERSION}"
#BUILD_DIR="$BASE_DIR/build-${VERSION}-${SNAPSHOT_DATE}"
BUILD_DIR="$BASE_DIR/build"
LOG_DIR="$BUILD_DIR/logs/$SNAPSHOT_DATE"

mkdir -p "$BUILD_DIR" "$LOG_DIR"
cp "$CMAKE_FILE" "$BASE_DIR/CMakeLists.txt"

log "Build directory: $BUILD_DIR"

# -------- Spack environment --------------------------------------------------
log "Activating Spack environment..."
source "$SPACK_DIR/start_spack_bundle.sh"

# -------- CMake configure ----------------------------------------------------
if [[ "$RUN_CMAKE" == true ]]; then
  log "Running CMake... (precision=$PRECISION, noreomote=ON)"
  (
    cd "$BUILD_DIR"
    cmake .. \
      -DMPAS_DOUBLE_PRECISION="$PRECISION" \
      -DMPAS_BUNDLE_NOREMOTE=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_VERBOSE_MAKEFILE=ON \
      2>&1 | tee "$LOG_DIR/cmake_${JOBSTAMP}.log"
  )
else
  log "Skipping CMake configuration step (--no-cmake used)"
fi

# -------- Build & Test pipeline ----------------------------------------------
log "Dispatching build/tests ($MODE mode)..."
bash "$SCRIPT_DIR/lib/submit_jobs.sh" -s "$SCRIPT_DIR" -b "$BUILD_DIR" -e "$SPACK_DIR" -c "gnu" -p "$PRECISION" -m "$MODE"

log "Workflow submitted. Check SLURM queue or logs under $LOG_DIR."

