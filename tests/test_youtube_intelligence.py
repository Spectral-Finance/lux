import unittest
from youtube_intelligence import YouTubeContentIntelligence

class TestYouTubeContentIntelligence(unittest.TestCase):
    def setUp(self):
        self.agent = YouTubeContentIntelligence("CH_TEST_01")

    def test_velocity_engine_high_trajectory(self):
        # 5000 views in 2 hours = 2500 VPH. Historical is 1000. Score should be 2.5
        metrics = self.agent.analyze_performance(views=5000, hours_live=2.0, avd_sec=180, video_len_sec=600, historical_vph=1000)
        self.assertEqual(metrics.vph, 2500.0)
        self.assertEqual(metrics.velocity_score, 2.5)
        self.assertIn("High velocity - potential viral trajectory", metrics.retention_flags)

    def test_engagement_grading_s_tier(self):
        # 10k views, 600 likes (0.06 ratio), 60 comments (6 per 1k views) -> Should be 'S' tier
        metrics = self.agent.grade_engagement(likes=600, views=10000, comments=60)
        self.assertEqual(metrics.grade, "S")

    def test_ctr_optimizer_logic(self):
        result = self.agent.optimize_title_ctr("The INSANE Secret to 10x Your AI Agents [Exposed]")
        self.assertTrue(result.has_power_words)
        self.assertTrue(result.has_brackets)
        self.assertGreater(result.score, 80)

if __name__ == "__main__":
    unittest.main()
