"""
YouTube Data API v3 Client — Spectral-Finance/lux Bounty #69
Implements YouTube API client for video search, channel data, and content intelligence.
Bounty: $2,500 — YouTube Content Intelligence System
"""

import os
import json
import urllib.parse
import urllib.request
from typing import Optional, Dict, Any, List
from datetime import datetime


class YouTubeAPIError(Exception):
    """Raised when YouTube API returns an error."""
    pass


class YouTubeClient:
    """
    YouTube Data API v3 client for content intelligence.
    Supports video search, channel data, video statistics, and keyword analysis.
    """

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("YOUTUBE_API_KEY")
        if not self.api_key:
            raise YouTubeAPIError("YouTube API key not configured")
        self.api_base = "https://www.googleapis.com/youtube/v3"

    # ---------- Core API ----------

    def _request(
        self,
        endpoint: str,
        params: Optional[Dict] = None,
    ) -> Dict[str, Any]:
        """Execute YouTube API request."""
        if params is None:
            params = {}
        params["key"] = self.api_key
        url = f"{self.api_base}/{endpoint}?{urllib.parse.urlencode(params)}"

        req = urllib.request.Request(url, headers={"User-Agent": "YouTubeClient/1.0"})
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                raw = resp.read()
                if not raw:
                    return {}
                return json.loads(raw.decode("utf-8"))
        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8", errors="replace")
            raise YouTubeAPIError(f"YouTube API HTTP error {e.code}: {error_body}")

    # ---------- Video Endpoints ----------

    def get_video(self, video_id: str, parts: Optional[List[str]] = None) -> Dict[str, Any]:
        """Get video details by ID."""
        if parts is None:
            parts = ["snippet", "statistics", "contentDetails"]
        params = {"id": video_id, "part": ",".join(parts)}
        result = self._request("videos", params)
        items = result.get("items", [])
        return items[0] if items else {}

    def search_videos(
        self,
        query: str,
        max_results: int = 25,
        order: str = "relevance",
        video_type: str = "video",
        published_after: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        """Search for videos by query."""
        params = {
            "q": query,
            "part": "snippet",
            "maxResults": max_results,
            "order": order,
            "type": video_type,
        }
        if published_after:
            params["publishedAfter"] = published_after
        result = self._request("search", params)
        return result.get("items", [])

    def get_video_statistics(self, video_id: str) -> Dict[str, Any]:
        """Get video statistics (views, likes, comments)."""
        video = self.get_video(video_id, parts=["statistics"])
        return video.get("statistics", {})

    # ---------- Channel Endpoints ----------

    def get_channel(self, channel_id: str, parts: Optional[List[str]] = None) -> Dict[str, Any]:
        """Get channel details by ID."""
        if parts is None:
            parts = ["snippet", "statistics", "contentDetails"]
        params = {"id": channel_id, "part": ",".join(parts)}
        result = self._request("channels", params)
        items = result.get("items", [])
        return items[0] if items else {}

    def get_channel_by_username(self, username: str) -> Dict[str, Any]:
        """Get channel details by username (for legacy compatibility)."""
        params = {"forUsername": username, "part": "snippet,statistics,contentDetails"}
        result = self._request("channels", params)
        items = result.get("items", [])
        return items[0] if items else {}

    def get_channel_statistics(self, channel_id: str) -> Dict[str, Any]:
        """Get channel statistics (subscribers, views, video count)."""
        channel = self.get_channel(channel_id, parts=["statistics"])
        return channel.get("statistics", {})

    def get_channel_uploads(self, channel_id: str, max_results: int = 50) -> List[Dict[str, Any]]:
        """Get recent uploads from a channel."""
        # First get the contentDetails to find the uploads playlist ID
        channel = self.get_channel(channel_id, parts=["contentDetails"])
        related_playlists = channel.get("contentDetails", {}).get("relatedPlaylists", {})
        uploads_playlist_id = related_playlists.get("uploads")

        if not uploads_playlist_id:
            return []

        params = {
            "part": "snippet",
            "playlistId": uploads_playlist_id,
            "maxResults": max_results,
        }
        result = self._request("playlistItems", params)
        return result.get("items", [])

    # ---------- Content Intelligence ----------

    def analyze_video_engagement(self, video_id: str) -> Dict[str, Any]:
        """Analyze video engagement metrics."""
        video = self.get_video(video_id, parts=["snippet", "statistics"])
        stats = video.get("statistics", {})
        snippet = video.get("snippet", {})

        view_count = int(stats.get("viewCount", 0))
        like_count = int(stats.get("likeCount", 0))
        comment_count = int(stats.get("commentCount", 0))

        engagement_rate = 0.0
        if view_count > 0:
            engagement_rate = ((like_count + comment_count) / view_count) * 100

        return {
            "video_id": video_id,
            "title": snippet.get("title", ""),
            "channel_title": snippet.get("channelTitle", ""),
            "published_at": snippet.get("publishedAt", ""),
            "view_count": view_count,
            "like_count": like_count,
            "comment_count": comment_count,
            "engagement_rate_percent": round(engagement_rate, 2),
        }

    def extract_keywords_from_title(self, title: str) -> List[str]:
        """Extract potential keywords from a video title."""
        # Simple keyword extraction: split on common delimiters, filter short words
        import re

        words = re.findall(r"\b\w{3,}\b", title.lower())
        stop_words = {
            "the", "and", "for", "with", "from", "this", "that", "how",
            "what", "why", "when", "where", "who", "which", "you", "are",
            "was", "been", "have", "has", "had", "will", "would", "could",
            "should", "may", "might", "must", "can", "get", "got", "just",
            "like", "love", "best", "top", "new", "old", "big", "small",
        }
        keywords = [w for w in words if w not in stop_words]
        # Deduplicate while preserving order
        seen = set()
        unique_keywords = []
        for k in keywords:
            if k not in seen:
                seen.add(k)
                unique_keywords.append(k)
        return unique_keywords[:10]

    def analyze_channel_content(self, channel_id: str) -> Dict[str, Any]:
        """Analyze a channel's content for intelligence."""
        channel = self.get_channel(channel_id, parts=["snippet", "statistics"])
        stats = channel.get("statistics", {})
        snippet = channel.get("snippet", {})

        uploads = self.get_channel_uploads(channel_id, max_results=20)

        video_titles = []
        total_views = 0
        total_likes = 0
        total_comments = 0

        for item in uploads:
            snippet_item = item.get("snippet", {})
            title = snippet_item.get("title", "")
            video_titles.append(title)

            # Get detailed stats for each video
            resource_id = snippet_item.get("resourceId", {})
            video_id = resource_id.get("videoId")
            if video_id:
                try:
                    video_stats = self.get_video_statistics(video_id)
                    total_views += int(video_stats.get("viewCount", 0))
                    total_likes += int(video_stats.get("likeCount", 0))
                    total_comments += int(video_stats.get("commentCount", 0))
                except YouTubeAPIError:
                    pass

        # Extract keywords from all titles
        all_keywords = []
        for title in video_titles:
            all_keywords.extend(self.extract_keywords_from_title(title))

        # Count keyword frequency
        keyword_freq: Dict[str, int] = {}
        for kw in all_keywords:
            keyword_freq[kw] = keyword_freq.get(kw, 0) + 1

        top_keywords = sorted(keyword_freq.items(), key=lambda x: x[1], reverse=True)[:10]

        return {
            "channel_id": channel_id,
            "channel_title": snippet.get("title", ""),
            "subscriber_count": int(stats.get("subscriberCount", 0)),
            "view_count": int(stats.get("viewCount", 0)),
            "video_count": int(stats.get("videoCount", 0)),
            "recent_uploads_analyzed": len(uploads),
            "total_recent_views": total_views,
            "total_recent_likes": total_likes,
            "total_recent_comments": total_comments,
            "top_keywords": top_keywords,
        }


if __name__ == "__main__":
    # Example usage (requires YOUTUBE_API_KEY env var)
    try:
        client = YouTubeClient()
        print("YouTube Client initialized")
        print(f"API Key: {'Set' if client.api_key else 'Not set'}")
    except YouTubeAPIError as e:
        print(f"YouTube client not configured: {e}")