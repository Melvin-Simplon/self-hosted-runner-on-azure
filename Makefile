SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

# Every target is a shortcut to the toolkit: the logic lives in scripts/runner.sh and scripts/lib/
RUNNER := scripts/runner.sh

include makefiles/common.mk
include makefiles/bootstrap.mk
