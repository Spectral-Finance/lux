"""End-to-end example: collect -> predict -> revenue -> report (sample data)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from youtube_analytics import YouTubeCollector, build_report, export_csv, estimate_revenue


def main() -> None:
    collector = YouTubeCollector(api_key=None)  # replace with your key for real data
    snapshot = collector.collect("UC_sample_channel", max_videos=7)

    print(f"Channel: {snapshot.channel.title} | subs={snapshot.channel.subscriber_count:,}")
    print(f"Videos collected: {len(snapshot.videos)} | comments: {len(snapshot.comments)}")

    est = estimate_revenue(snapshot.channel.view_count, rpm=3.0)
    print(f"Channel-level revenue estimate: gross=${est['gross_usd']} net=${est['net_usd']}")

    report = build_report(snapshot, rpm=3.0, forecast_steps=7)
    print("\n" + report[:1500] + "\n...")

    with open("report.md", "w", encoding="utf-8") as fh:
        fh.write(report)
    with open("videos.csv", "w", encoding="utf-8") as fh:
        fh.write(export_csv(snapshot.videos))
    print("[ok] wrote report.md and videos.csv")


if __name__ == "__main__":
    main()
