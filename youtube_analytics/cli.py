"""CLI entry point for the YouTube Analytics & Growth Engine.

Examples:
  python -m youtube_analytics.cli collect UC_x5XG1OV2P6uZZ5FSM9Ttw
  python -m youtube_analytics.cli report UC_x5XG1OV2P6uZZ5FSM9Ttw --out report.md
  python -m youtube_analytics.cli csv UC_x5XG1OV2P6uZZ5FSM9Ttw --out videos.csv
"""
from __future__ import annotations

import argparse
import sys

from .collector import YouTubeCollector
from .reporting import build_report, export_csv


def _collector(args) -> YouTubeCollector:
    return YouTubeCollector(api_key=args.api_key or None)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="youtube-analytics")
    parser.add_argument("--api-key", default=None, help="YouTube Data API v3 key (or set YOUTUBE_API_KEY)")
    sub = parser.add_subparsers(dest="command", required=True)

    p_collect = sub.add_parser("collect", help="采集频道/视频/评论指标")
    p_collect.add_argument("channel_id")
    p_collect.add_argument("--max-videos", type=int, default=25)

    p_report = sub.add_parser("report", help="生成 Markdown 报告")
    p_report.add_argument("channel_id")
    p_report.add_argument("--out", default="-")
    p_report.add_argument("--rpm", type=float, default=3.0)

    p_csv = sub.add_parser("csv", help="导出视频指标 CSV")
    p_csv.add_argument("channel_id")
    p_csv.add_argument("--out", default="-")

    args = parser.parse_args(argv)
    col = _collector(args)

    if args.command == "collect":
        snap = col.collect(args.channel_id, max_videos=args.max_videos)
        print(snap.to_dict())
    elif args.command == "report":
        snap = col.collect(args.channel_id)
        report = build_report(snap, rpm=args.rpm)
        if args.out == "-":
            print(report)
        else:
            with open(args.out, "w", encoding="utf-8") as fh:
                fh.write(report)
            print(f"[ok] 报告已写入 {args.out}")
    elif args.command == "csv":
        snap = col.collect(args.channel_id)
        data = export_csv(snap.videos)
        if args.out == "-":
            sys.stdout.write(data)
        else:
            with open(args.out, "w", encoding="utf-8") as fh:
                fh.write(data)
            print(f"[ok] CSV 已写入 {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
