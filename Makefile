# OpenDeck — root Makefile
#
#   make dev      run open-deck-server locally (debug build)
#   make dev-rel  run open-deck-server locally (release build)
#   make dev-web  server + web dashboard dev servers together
#   make build    cargo build --release in server/
#   make test     cargo test in server/
#   make lint     cargo fmt --check + clippy in server/
#
#   make web      build the web UI (mobile/web) and copy dist/ into server/web
#
# Server flags: --port (default 47821), --fps, --quality, --max-width,
# --bind, --token, --actions. The web UI is served at http://localhost:47821/

PORT ?= 47821

.PHONY: dev dev-rel dev-web build test lint web

dev: ## Start the companion server locally (debug)
	cd server && cargo run -- --port $(PORT)

dev-rel: ## Start the companion server locally (release)
	cd server && cargo run --release -- --port $(PORT)

dev-web: ## Server + web dashboard together (fixed dev token)
	(cd server && cargo run -- --port $(PORT) --token dev) & \
	trap 'kill %1' INT TERM EXIT; \
	VITE_TOKEN=dev pnpm --filter @opendeck/web dev

build: ## Release-build the server
	cd server && cargo build --release

test: ## Run server tests
	cd server && cargo test

lint: ## Format check + clippy for the server
	cd server && cargo fmt --all -- --check
	cd server && cargo clippy --all-targets -- -D warnings

web: ## Build mobile/web (Vite) and copy dist/ into server/web
	pnpm install
	pnpm --filter @opendeck/web build
	rm -rf server/web && cp -r mobile/web/dist server/web
