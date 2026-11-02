defmodule Lux.Integrations.Telegram.MessageProcessing.ContentAnalyzerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.MessageProcessing.ContentAnalyzer

  describe "analyze/1 with different message types" do
    test "classifies plain text messages and computes text statistics" do
      msg = %{
        "message_id" => 101,
        "date" => 1_700_000_000,
        "from" => %{
          "id" => 987_654,
          "is_bot" => false,
          "first_name" => "Alice",
          "username" => "alice_eth"
        },
        "chat" => %{
          "id" => -100_123_456,
          "type" => "supergroup",
          "title" => "Lux Devs"
        },
        "text" => "/swap ETH to USDC 10\nCheck http://spectral.finance"
      }

      assert {:ok, result} = ContentAnalyzer.analyze(msg)
      assert result.message_id == 101
      assert result.message_type == :text
      assert result.sender.username == "alice_eth"
      assert result.chat.type == "supergroup"
      assert result.text_stats.char_count > 0
      assert result.text_stats.word_count == 7
      assert result.text_stats.has_commands == true
      assert result.text_stats.has_links == true
      assert result.flags.has_media == false
    end

    test "classifies photo messages and extracts photo sizes and caption" do
      msg = %{
        message_id: 102,
        date: 1_700_000_100,
        from: %{id: 111, first_name: "Bob"},
        chat: %{id: 111, type: "private"},
        photo: [
          %{file_id: "thumb_id", file_unique_id: "u1", width: 100, height: 100, file_size: 500},
          %{file_id: "full_id", file_unique_id: "u2", width: 800, height: 800, file_size: 15_000}
        ],
        caption: "New chart update"
      }

      assert {:ok, result} = ContentAnalyzer.analyze(msg)
      assert result.message_type == :photo
      assert result.media_info.type == :photo
      assert result.media_info.file_id == "full_id"
      assert result.media_info.width == 800
      assert result.media_info.caption == "New chart update"
      assert result.flags.has_media == true
    end

    test "classifies video, audio, voice, and document messages" do
      video_msg = %{
        message_id: 103,
        video: %{file_id: "vid_1", duration: 120, width: 1920, height: 1080, file_size: 10_000_000}
      }

      assert {:ok, vid_res} = ContentAnalyzer.analyze(video_msg)
      assert vid_res.message_type == :video
      assert vid_res.media_info.duration == 120

      doc_msg = %{
        message_id: 104,
        document: %{file_id: "doc_1", file_name: "whitepaper.pdf", mime_type: "application/pdf"}
      }

      assert {:ok, doc_res} = ContentAnalyzer.analyze(doc_msg)
      assert doc_res.message_type == :document
      assert doc_res.media_info.file_name == "whitepaper.pdf"
    end

    test "classifies location, contact, and poll messages" do
      loc_msg = %{
        message_id: 105,
        location: %{latitude: 37.7749, longitude: -122.4194}
      }

      assert {:ok, loc_res} = ContentAnalyzer.analyze(loc_msg)
      assert loc_res.message_type == :location
      assert loc_res.media_info.latitude == 37.7749

      poll_msg = %{
        message_id: 106,
        poll: %{id: "p_1", question: "Which token to buy?", total_voter_count: 50}
      }

      assert {:ok, poll_res} = ContentAnalyzer.analyze(poll_msg)
      assert poll_res.message_type == :poll
      assert poll_res.media_info.question == "Which token to buy?"
    end

    test "parses Telegram entities accurately" do
      text = "Check out @Spectral_Fi and https://spectral.finance for *updates*"

      msg = %{
        message_id: 107,
        text: text,
        entities: [
          %{type: "mention", offset: 10, length: 12},
          %{type: "url", offset: 27, length: 24}
        ]
      }

      assert {:ok, result} = ContentAnalyzer.analyze(msg)
      assert length(result.entities) == 2
      [mention, url] = result.entities
      assert mention.type == "mention"
      assert mention.value == "@Spectral_Fi"
      assert url.type == "url"
      assert url.value == "https://spectral.finance"
    end

    test "extracts message flags" do
      msg = %{
        message_id: 108,
        text: "Forwarded message",
        forward_date: 1_699_000_000,
        reply_to_message: %{message_id: 99},
        message_thread_id: 55,
        has_protected_content: true
      }

      assert {:ok, result} = ContentAnalyzer.analyze(msg)
      assert result.flags.is_forwarded == true
      assert result.flags.is_reply == true
      assert result.flags.is_topic_message == true
      assert result.flags.has_protected_content == true
    end

    test "returns error on non-map input" do
      assert {:error, _} = ContentAnalyzer.analyze("not a map")
    end
  end
end
