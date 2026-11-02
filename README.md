# YouTube Analytics and Growth Engine

Comprehensive analytics and growth-optimization system for YouTube channels —
submitted for [Spectral-Finance/lux bounty #72 ($2,000)](https://github.com/Spectral-Finance/lux/issues/72).

## Feature coverage (issue acceptance criteria)

| Criterion | Implementation |
| --- | --- |
| Analytics data collection system | `youtube_analytics/collector.py` — YouTube Data API v3 (channel/videos/comments), sample-data fallback |
| Growth prediction models | `youtube_analytics/prediction.py` — linear regression, exponential smoothing, CMGR |
| Revenue optimization tools | `youtube_analytics/revenue.py` — RPM/CPM estimation, segment ranking, rule-based tips |
| Automated reporting system | `youtube_analytics/reporting.py` — Markdown report + CSV export |
| Documentation and examples | This README + `examples/example.py` |
| Integration tests | `tests/test_pipeline.py` — full pipeline + algorithm unit tests (pytest) |

## Quick start

```bash
# No API key needed — runs on bundled sample data
python -m youtube_analytics.cli report UC_x5XG1OV2P6uZZ5FSM9Ttw --out report.md

# With a real YouTube Data API v3 key
export YOUTUBE_API_KEY=your_key
python -m youtube_analytics.cli collect UC_x5XG1OV2P6uZZ5FSM9Ttw --max-videos 25
python -m youtube_analytics.cli csv UC_x5XG1OV2P6uZZ5FSM9Ttw --out videos.csv
```

## Library API

```python
from youtube_analytics import YouTubeCollector, build_report

collector = YouTubeCollector(api_key=None)          # None → sample data
snapshot = collector.collect("UC_sample_channel", max_videos=7)
report = build_report(snapshot, rpm=3.0, forecast_steps=7)
print(report)
```

## Testing

```bash
python -m pytest tests/ -v
```

## Structure

```
youtube_analytics/
  __init__.py      # public API
  collector.py     # YouTube Data API v3 collection + sample fallback
  models.py        # Channel / Video / Comment dataclasses
  prediction.py    # linear / exponential / CMGR forecasts
  revenue.py       # revenue estimates + optimization tips
  reporting.py     # Markdown report + CSV export
  cli.py           # command-line interface
  sample_data.json # offline sample for demo & tests
examples/example.py
tests/test_pipeline.py
```
