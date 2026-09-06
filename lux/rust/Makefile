.PHONY: test build clean coverage setup

# Lux Rust Testing Makefile

test:
	cargo test -- --nocapture

test-verbose:
	cargo test -v -- --nocapture

coverage:
	cargo test -- --nocapture --coverage
	@echo "Coverage report generated"

setup:
	cargo build
	cargo test --no-run

clean:
	cargo clean
	rm -f priv/plts/*.plt 2>/dev/null || true

fmt:
	cargo fmt

clippy:
	cargo clippy -- -D warnings

doc:
	cargo doc --no-deps

bench:
	cargo bench

help:
	@echo "Lux Rust Testing Framework"
	@echo ""
	@echo "Targets:"
	@echo "  test        - Run all tests"
	@echo "  test-verbose- Run tests with verbose output"
	@echo "  coverage    - Run tests with coverage reporting"
	@echo "  setup       - Build and compile tests"
	@echo "  clean       - Clean build artifacts"
	@echo "  fmt         - Format code"
	@echo "  clippy      - Run linter"
	@echo "  doc         - Generate documentation"
	@echo "  bench       - Run benchmarks"
