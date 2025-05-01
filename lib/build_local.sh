#!/usr/bin/env bash
###############################################################################
# build_local.sh
# -----------------------------------------------------------------------------
# Lightweight *local* compilation helper for MPAS‑JEDI on the Egeon login node.
# -----------------------------------------------------------------------------
# Maintainer : João Gerd Zell de Mattos <joao.gerd@gmail.com>
# Created    : 2025‑04‑?? (original version)
# Last update: 2025-04-24
#
# PURPOSE
# =======
# Compile an already‑configured **mpas‑bundle** build tree directly on the login
# node with minimal impact on other users:
#   • Caps threads to 10 % of logical CPUs (≥1)
#   • Demotes priority via *nice* + *ionice*
#   • Requires that CMake configuration was performed beforehand (e.g. by
#     build_and_test.sh) and that a Spack‑Stack environment is active.
#
# USAGE
# -----
#   ./build_local.sh <BUILD_DIR> <SPACK_DIR> [COMPILER] [PRECISION]
#
# Arguments
#   BUILD_DIR   Path to CMake build directory (with Makefiles already present)
#   SPACK_DIR   Root of the activated Spack‑Stack env (for module paths)
#   COMPILER    Just forwarded for informational purposes (default: gnu)
#   PRECISION   "ON" | "OFF" – informational only (default: ON)
#
# EXIT CODES
# ----------
#  0  success
#  1  missing dependencies or user error
#  2  compilation failure
###############################################################################

set -Eeuo pipefail

# -------- helper -------------------------------------------------------------
log() { printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
die() { printf '[%(%F %T)T] [ERROR] %s\n' -1 "$*" >&2; exit 1; }
trap 'log "[ERROR] line $LINENO – exiting."; exit 2' ERR

# -------- arguments ----------------------------------------------------------
BUILD_DIR="${1:?BUILD_DIR missing}"
SPACK_DIR="${2:?SPACK_DIR missing}"
COMPILER="${3:-gnu}"
PRECISION="${4:-ON}"
# Prevent accidental propagation of this script's positional parameters.
set --

[[ -d "$BUILD_DIR" ]] || die "BUILD_DIR not found: $BUILD_DIR"
[[ -d "$SPACK_DIR" ]] || die "SPACK_DIR not found: $SPACK_DIR"

log "[INFO] Local build started (compiler=$COMPILER, precision=$PRECISION)"
log "[INFO] BUILD_DIR = $BUILD_DIR"

# -------- Spack environment --------------------------------------------------
log "[INFO] Activating Spack environment..."
source "$SPACK_DIR/start_spack_bundle.sh"

# -------- thread cap ---------------------------------------------------------
TOTAL_CPUS=$(nproc)
MAKE_J=$(( TOTAL_CPUS / 10 ))
[[ "$MAKE_J" -lt 1 ]] && MAKE_J=1
log "Limiting build to $MAKE_J thread(s) out of $TOTAL_CPUS CPUs"

# -------- compilation --------------------------------------------------------
cd "$BUILD_DIR"
log "Running make -j$MAKE_J with low I/O & CPU priority …"
nice -n 19 ionice -c3 make -j"$MAKE_J"

log "Compilation completed successfully!"

