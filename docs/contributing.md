# Contributing to Lux

## Development Setup
```bash
git clone https://github.com/Spectral-Finance/lux.git
cd lux
npm install
cp .env.example .env
npm run dev
```

## Project Structure
```
lux/
├── src/
│   ├── agents/          # Agent implementations
│   ├── api/             # REST API handlers
│   ├── core/            # Core engine
│   ├── signals/         # Signal processing
│   ├── storage/         # Persistence layer
│   └── utils/           # Shared utilities
├── docs/                # Documentation
├── tests/               # Test suite
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── scripts/             # Dev/CI scripts
└── config/              # Configuration templates
```

## Code Style
- TypeScript strict mode enabled
- ESLint with `@spectral-finance/eslint-config`
- Prettier for formatting
- Conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`

## Testing
```bash
# Unit tests
npm test

# Integration tests
npm run test:integration

# E2E tests
npm run test:e2e

# Coverage
npm run test:coverage
```

## Commit Guidelines
```
feat: add signal processing pipeline
fix: resolve race condition in agent lifecycle
docs: update API reference
test: add unit tests for storage layer
refactor: simplify agent config parsing
```

## Pull Request Process
1. Fork and create branch: `feat/your-feature`
2. Write tests and documentation
3. Ensure CI passes (lint, type-check, test, build)
4. Open PR against `main` with description
5. Get review from maintainer
6. Squash merge on approval

## Release Process
1. Update version in `package.json`
2. Update CHANGELOG.md
3. Create release tag: `git tag v1.2.3`
4. Push tag: `git push --tags`
5. CI builds and publishes to npm

## Environment Variables
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `LUX_PORT` | No | 3000 | API server port |
| `LUX_LOG_LEVEL` | No | info | Logging level |
| `LUX_DB_PATH` | No | ./data | Database path |
| `LUX_MAX_AGENTS` | No | 10 | Max concurrent agents |

## Troubleshooting Dev Setup

| Symptom | Solution |
|---------|----------|
| `npm install` fails | Use Node >= 18, clear node_modules |
| Type errors | Run `npm run type-check` to see details |
| Test timeout | Increase timeout in `jest.config.ts` |
| Port conflict | Set `LUX_PORT` env var |
| DB locked | Delete `./data/` directory |
