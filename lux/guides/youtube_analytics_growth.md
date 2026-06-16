# YouTube Analytics and Growth Engine

This bounty implementation adds deterministic YouTube analytics and growth helpers under `Lux.Integrations.YouTube.AnalyticsGrowth` plus a prism wrapper at `Lux.Prisms.YouTube.GenerateGrowthReport`.

## Capabilities

- Normalizes YouTube video or channel metric snapshots.
- Collects current analytics totals, CTR, RPM, and latest content metrics.
- Predicts growth from historical snapshot deltas.
- Computes retention flags from average view duration and video length.
- Produces revenue optimization and ROI recommendations.
- Benchmarks against competitor rows.
- Generates report-ready chart data and audit checks.

The implementation is credential-neutral: callers can feed snapshots from YouTube Analytics API, exports, a warehouse job, or tests.
