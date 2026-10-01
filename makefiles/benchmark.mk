##@ Benchmark (last completed run, or RUN=<id>; other repository: REPO=<owner/name>)

.PHONY: bench-runs bench-logs bench-metrics

bench-runs: ## List the last completed runs and their id
	@REPO="$(REPO)" $(RUNNER) benchmark runs

bench-logs: ## Show the logs of a GitHub Actions run
	@REPO="$(REPO)" $(RUNNER) benchmark logs $(RUN)

bench-metrics: ## Total CI duration of a run, to the millisecond
	@REPO="$(REPO)" $(RUNNER) benchmark metrics $(RUN)
