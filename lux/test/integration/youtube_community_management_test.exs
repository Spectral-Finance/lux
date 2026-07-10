defmodule Lux.Integration.YouTubeCommunityManagementTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Integration test demonstrating comment management, automated response, sentiment analysis,
  and moderation capabilities for YouTube Community Management.
  """

  alias Lux.Lenses.YouTube.ListCommentThreads
  alias Lux.Prisms.YouTube.ClassifyComment
  alias Lux.Prisms.YouTube.ReplyToComment
  alias Lux.Prisms.YouTube.ModerateComment

  alias Lux.Integrations.YouTube.Client, as: YouTubeClient

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "end-to-end community management flow: fetch comments, classify, reply to positive, moderate spam/abuse" do
    # 1. Fetch Comments
    Req.Test.expect(YouTubeClient, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/commentThreads"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "items" => [
          %{
            "id" => "comment_pos",
            "snippet" => %{
              "videoId" => "vid1",
              "topLevelComment" => %{
                "snippet" => %{
                  "textDisplay" => "This video is amazing and very helpful!",
                  "textOriginal" => "This video is amazing and very helpful!",
                  "authorDisplayName" => "HappyUser"
                }
              }
            }
          },
          %{
            "id" => "comment_scam",
            "snippet" => %{
              "videoId" => "vid1",
              "topLevelComment" => %{
                "snippet" => %{
                  "textDisplay" => "whatsapp me on +1234567 for guaranteed crypto profit",
                  "textOriginal" => "whatsapp me on +1234567 for guaranteed crypto profit",
                  "authorDisplayName" => "ScamBot"
                }
              }
            }
          },
          %{
            "id" => "comment_link_spam",
            "snippet" => %{
              "videoId" => "vid1",
              "topLevelComment" => %{
                "snippet" => %{
                  "textDisplay" => "https://spamlink.xyz/abc",
                  "textOriginal" => "https://spamlink.xyz/abc",
                  "authorDisplayName" => "SpamBot"
                }
              }
            }
          },
          %{
            "id" => "comment_abusive",
            "snippet" => %{
              "videoId" => "vid1",
              "topLevelComment" => %{
                "snippet" => %{
                  "textDisplay" => "This is absolute shit, you are a scumbag!",
                  "textOriginal" => "This is absolute shit, you are a scumbag!",
                  "authorDisplayName" => "AngryTroll"
                }
              }
            }
          },
          %{
            "id" => "comment_escalate",
            "snippet" => %{
              "videoId" => "vid1",
              "topLevelComment" => %{
                "snippet" => %{
                  "textDisplay" => "The page keeps crashing and showing an error.",
                  "textOriginal" => "The page keeps crashing and showing an error.",
                  "authorDisplayName" => "FrustratedUser"
                }
              }
            }
          },
          %{
            "id" => "comment_no_action",
            "snippet" => %{
              "videoId" => "vid1",
              "topLevelComment" => %{
                "snippet" => %{
                  "textDisplay" => "ok",
                  "textOriginal" => "ok",
                  "authorDisplayName" => "QuietUser"
                }
              }
            }
          },
          %{
            "id" => "comment_neutral",
            "snippet" => %{
              "videoId" => "vid1",
              "topLevelComment" => %{
                "snippet" => %{
                  "textDisplay" => "What time is the next live stream?",
                  "textOriginal" => "What time is the next live stream?",
                  "authorDisplayName" => "CuriousUser"
                }
              }
            }
          }
        ]
      }))
    end)

    assert {:ok, %{comments: comments}} = ListCommentThreads.focus(
      %{video_id: "vid1"},
      plug: {Req.Test, YouTubeClient}
    )

    assert length(comments) == 7

    # Setup the expected HTTP mock requests for mutating actions.
    # 1. Reply to Positive comment
    Req.Test.expect(YouTubeClient, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/comments"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      json_body = Jason.decode!(body)
      assert json_body["snippet"]["parentId"] == "comment_pos"
      assert json_body["snippet"]["textOriginal"] == "Thank you so much for the support! Glad you found it helpful."

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "id" => "reply_pos",
        "snippet" => %{"textOriginal" => "Thank you so much for the support! Glad you found it helpful."}
      }))
    end)

    # 2. Moderate scam comment (reject/hide)
    Req.Test.expect(YouTubeClient, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/comments/setModerationStatus"
      assert conn.params["id"] == "comment_scam"
      assert conn.params["moderationStatus"] == "rejected"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(204, "")
    end)

    # 3. Moderate link-only comment (reject/hide)
    Req.Test.expect(YouTubeClient, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/comments/setModerationStatus"
      assert conn.params["id"] == "comment_link_spam"
      assert conn.params["moderationStatus"] == "rejected"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(204, "")
    end)

    # 4. Moderate abusive comment (reject/hide)
    Req.Test.expect(YouTubeClient, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/comments/setModerationStatus"
      assert conn.params["id"] == "comment_abusive"
      assert conn.params["moderationStatus"] == "rejected"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(204, "")
    end)

    # Process all comments using ClassifyComment decision pipeline
    for comment <- comments do
      assert {:ok, decision} = ClassifyComment.handler(%{
        text: comment.text_original,
        author_display_name: comment.author_display_name
      }, %{name: "CommunityManager"})

      case {comment.id, decision.state} do
        {"comment_pos", "reply"} ->
          # Execute reply (dry_run: false to hit live/mocked Req stub)
          assert {:ok, %{replied: true}} = ReplyToComment.handler(%{
            parent_id: comment.id,
            text: decision.recommended_reply,
            dry_run: false,
            plug: {Req.Test, YouTubeClient}
          }, %{name: "CommunityManager"})

        {id, "hide"} when id in ["comment_scam", "comment_link_spam", "comment_abusive"] ->
          # Execute moderation (dry_run: false to hit live/mocked Req stub)
          assert {:ok, %{moderated: true}} = ModerateComment.handler(%{
            comment_id: comment.id,
            moderation_status: "rejected",
            ban_author: false,
            dry_run: false,
            plug: {Req.Test, YouTubeClient}
          }, %{name: "CommunityManager"})

        {"comment_escalate", "escalate"} ->
          # Verified classification matches expected without executing API calls
          assert "technical support or system issue detected" in decision.reasons

        {"comment_no_action", "no-action"} ->
          # Verified classification matches expected without executing API calls
          assert "low-engagement neutral greeting/acknowledgement" in decision.reasons

        {"comment_neutral", "review"} ->
          # Verified classification matches expected without executing API calls
          assert "unclassified comment pattern" in decision.reasons
      end
    end
  end
end
