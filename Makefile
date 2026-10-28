.PHONY: install build test snapshot prove clean docs

export DBT_PROFILES_DIR := $(CURDIR)

install:            ## install dbt + duckdb
	pip install -r requirements.txt

seeds:              ## regenerate the synthetic data
	python scripts/generate_seeds.py

build:              ## seed, run and test everything
	dbt build

snapshot:           ## freeze the period's payroll
	dbt snapshot

prove:              ## show the guardrails catch what they claim to
	python scripts/prove_guardrails.py
	python scripts/prove_point_in_time.py

docs:               ## generate and serve the dbt docs site locally
	dbt docs generate && dbt docs serve

docs-static:        ## build the single-file docs site (what CI publishes)
	dbt docs generate --static
	mkdir -p site && cp target/static_index.html site/index.html
	@echo "site/index.html"

clean:
	rm -rf target logs site commission_engine.duckdb commission_engine.duckdb.wal
