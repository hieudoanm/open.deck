# OpenDeck — root Makefile
#
#   make dev      run open-deck-server locally (debug build)
#   make dev-rel  run open-deck-server locally (release build)
#   make build    cargo build --release in server/
#   make test     cargo test in server/
#   make lint     cargo fmt --check + clippy in server/
#
# Server flags: --port (default 47821), --fps, --quality, --max-width,
# --bind, --token, --actions. The web client is served at http://localhost:47821/

PORT ?= 47821

.PHONY: dev dev-rel build test lint run

dev: ## Start the companion server locally (debug)
	cd server && cargo run -- --port $(PORT)

dev-rel: ## Start the companion server locally (release)
	cd server && cargo run --release -- --port $(PORT)

build: ## Release-build the server
	cd server && cargo build --release

test: ## Run server tests
	cd server && cargo test

lint: ## Format check + clippy for the server
	cd server && cargo fmt --all -- --check
	cd server && cargo clippy --all-targets -- -D warnings
