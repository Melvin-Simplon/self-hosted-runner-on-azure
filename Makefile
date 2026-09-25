SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

LOG_FILE ?= .logs/make.log

# Exported, never passed as positional arguments: scripts read the environment
export LOG_FILE

include makefiles/bootstrap.mk
include makefiles/common.mk
