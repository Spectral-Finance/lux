from lux import YouTubeIntelligencePrism


def test_youtube_intelligence_prism_handler():
    prism = YouTubeIntelligencePrism()
    result = prism.handler(
        {
            "views": 10000,
            "hours_since_publish": 5.0,
            "likes": 600,
            "comments": 120,
            "avg_view_duration": 300.0,
            "video_duration": 600.0,
        },
        context={},
    )
    assert result["performance"]["vph"] == 2000.0
    assert result["performance"]["apv_percentage"] == 50.0
    assert "high_velocity" in result["performance"]["retention_flags"]
    assert result["engagement"]["grade"] == "A"