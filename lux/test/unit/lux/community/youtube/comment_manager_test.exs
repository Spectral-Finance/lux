defmodule Lux.Community.YouTube.CommentManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Community.YouTube.CommentManager

  @sample_raw_thread %{
    id: "thread_101",
    snippet: %{
      videoId: "vid_abc123",
      totalReplyCount: 1,
      topLevelComment: %{
        snippet: %{
          videoId: "vid_abc123",
          authorDisplayName: "CodeExplorer",
          authorChannelId: %{"value" => "UC_channel_1"},
          textDisplay: "This is a great explanation of Elixir OTP!",
          likeCount: 42,
          publishedAt: "2026-11-01T12:00:00Z",
          moderationStatus: "published"
        }
      }
    },
    replies: %{
      comments: [
        %{
          id: "sub_1",
          snippet: %{
            authorDisplayName: "Channel Host",
            textDisplay: "Glad it helped!",
            publishedAt: "2026-11-01T12:10:00Z"
          }
        }
      ]
    }
  }

  describe "normalize_comment_thread/1" do
    test "correctly extracts fields from YouTube API structure" do
      comment = CommentManager.normalize_comment_thread(@sample_raw_thread)

      assert comment.id == "thread_101"
      assert comment.video_id == "vid_abc123"
      assert comment.author_name == "CodeExplorer"
      assert comment.author_channel_id == "UC_channel_1"
      assert comment.text == "This is a great explanation of Elixir OTP!"
      assert comment.like_count == 42
      assert comment.reply_count == 1
      assert comment.status == :published
      assert length(comment.replies) == 1
    end
  end

  describe "filter_comments/2 and sort_comments/2" do
    setup do
      c1 = %{
        id: "1",
        video_id: "v1",
        author_name: "Alice",
        author_channel_id: "c1",
        text: "Amazing video tutorial",
        published_at: "2026-11-01T10:00:00Z",
        like_count: 10,
        reply_count: 2,
        status: :published,
        is_pinned: false,
        replies: []
      }

      c2 = %{
        id: "2",
        video_id: "v1",
        author_name: "Bob",
        author_channel_id: "c2",
        text: "Crypto investment scam whatsapp me",
        published_at: "2026-11-01T11:00:00Z",
        like_count: 0,
        reply_count: 0,
        status: :likely_spam,
        is_pinned: false,
        replies: []
      }

      c3 = %{
        id: "3",
        video_id: "v2",
        author_name: "Charlie",
        author_channel_id: "c3",
        text: "Question about Phoenix LiveView",
        published_at: "2026-11-01T12:00:00Z",
        like_count: 50,
        reply_count: 5,
        status: :published,
        is_pinned: true,
        replies: []
      }

      {:ok, comments: [c1, c2, c3]}
    end

    test "filters comments by status and video_id", %{comments: comments} do
      published = CommentManager.filter_comments(comments, status: :published)
      assert length(published) == 2

      spam = CommentManager.filter_comments(comments, status: :likely_spam)
      assert length(spam) == 1
      assert hd(spam).id == "2"

      v2_comments = CommentManager.filter_comments(comments, video_id: "v2")
      assert length(v2_comments) == 1
      assert hd(v2_comments).id == "3"
    end

    test "sorts comments by likes and replies", %{comments: comments} do
      sorted_likes = CommentManager.sort_comments(comments, :likes)
      assert hd(sorted_likes).id == "3"
      assert List.last(sorted_likes).id == "2"

      sorted_replies = CommentManager.sort_comments(comments, :replies)
      assert hd(sorted_replies).id == "3"
    end
  end

  describe "add_reply/3, update_status/2, toggle_pin/1" do
    test "mutates comment thread state correctly" do
      comment = CommentManager.normalize_comment_thread(@sample_raw_thread)

      with_reply = CommentManager.add_reply(comment, "Thanks for the feedback!")
      assert with_reply.reply_count == 2
      assert length(with_reply.replies) == 2

      rejected = CommentManager.update_status(comment, :rejected)
      assert rejected.status == :rejected

      pinned = CommentManager.toggle_pin(comment)
      assert pinned.is_pinned == true
    end
  end
end
