defmodule Lux.Integrations.Telegram.AnalyticsTest do
  use ExUnit.Case

  alias Lux.Integrations.Telegram.Analytics

  @sample_messages [
    %{
      id: 1,
      date: "2026-06-15T10:00:00",
      from: %{id: 100, username: "admin", first_name: "Admin"},
      text: "Great news! Our project is doing amazing this week.",
      replies: [%{id: 11, text: "Awesome!"}, %{id: 12, text: "Love this"}],
      forwards: 5,
      views: 1200
    },
    %{
      id: 2,
      date: "2026-06-15T12:00:00",
      from: %{id: 100, username: "admin", first_name: "Admin"},
      text: "Market crash incoming, very bad and terrible situation.",
      replies: [%{id: 13, text: "Scam project!!"}],
      forwards: 2,
      views: 800
    },
    %{
      id: 3,
      date: "2026-06-16T09:00:00",
      from: %{id: 100, username: "admin", first_name: "Admin"},
      text: "New partnership announcement coming soon.",
      replies: [],
      forwards: 10,
      views: 2500
    },
    %{
      id: 4,
      date: "2026-06-17T14:00:00",
      from: %{id: 100, username: "admin", first_name: "Admin"},
      text: "Weekly update: solid progress on all fronts.",
      replies: [%{id: 14, text: "Excited to see this"}, %{id: 15, text: "Fantastic work team"}, %{id: 16, text: "Impressive results"}],
      forwards: 8,
      views: 3000
    },
    %{
      id: 5,
      date: "2026-06-18T08:00:00",
      from: %{id: 100, username: "admin", first_name: "Admin"},
      text: "",
      replies: [],
      forwards: 0,
      views: 100
    }
  ]

  @sample_members [
    %{id: 1, username: "user_a", joined_at: "2026-06-01T00:00:00"},
    %{id: 2, username: "user_b", joined_at: "2026-06-10T00:00:00"},
    %{id: 3, username: "user_c", joined_at: "2026-06-14T00:00:00"},
    %{id: 4, username: "user_d", joined_at: "2026-06-18T00:00:00"},
    %{id: 5, username: "user_e", joined_at: "2026-06-20T00:00:00"}
  ]

  describe "analyze_growth/3" do
    test "returns growth summary with net change" do
      result = Analytics.analyze_growth(@sample_members, @sample_messages, "7d")

      assert result[:period] == "7d"
      assert result[:start_date] != nil
      assert result[:end_date] != nil
      assert is_integer(result[:net_change])
      assert result[:new_members] >= 0
      assert result[:churned_members] >= 0
      assert is_list(result[:daily_breakdown])
    end

    test "handles empty inputs" do
      result = Analytics.analyze_growth([], [], "30d")
      assert result[:net_change] == 0
      assert result[:start_count] == 0
      assert is_list(result[:daily_breakdown])
    end
  end

  describe "engagement_metrics/1" do
    test "computes correct averages" do
      result = Analytics.engagement_metrics(@sample_messages)

      assert result[:message_count] == 4
      assert is_float(result[:average_replies_per_message])
      assert is_float(result[:average_forwards])
      assert is_float(result[:average_views])
      assert is_float(result[:reply_rate])
      assert is_integer(result[:replied_messages])
      assert is_integer(result[:total_forwards])
      assert is_integer(result[:total_views])
      assert is_integer(result[:engagement_score])
      assert result[:engagement_score] >= 0
      assert result[:engagement_score] <= 100
    end

    test "empty messages returns safe defaults" do
      result = Analytics.engagement_metrics([])
      assert result[:message_count] == 0
      assert result[:engagement_score] == 0
    end

    test "high engagement produces higher score" do
      viral = [
        %{
          id: 1,
          text: "Huge update!",
          replies: [%{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}, %{id: 5},
                     %{id: 6}, %{id: 7}, %{id: 8}, %{id: 9}, %{id: 10}],
          forwards: 20,
          views: 10000
        }
      ]

      result = Analytics.engagement_metrics(viral)
      assert result[:engagement_score] > 50
    end
  end

  describe "message_performance/2" do
    test "ranks messages by engagement score descending" do
      result = Analytics.message_performance(@sample_messages, %{sort_by: :engagement, limit: 3})

      assert length(result) == 3
      assert result == Enum.sort(result, fn a, b -> a[:score] >= b[:score] end)
    end

    test "sorts by views" do
      result = Analytics.message_performance(@sample_messages, %{sort_by: :views, limit: 2})
      assert length(result) == 2
      assert hd(result)[:score] >= List.last(result)[:score]
    end

    test "sorts by replies" do
      result = Analytics.message_performance(@sample_messages, %{sort_by: :replies, limit: 3})
      assert length(result) == 3
    end

    test "sorts by forwards" do
      result = Analytics.message_performance(@sample_messages, %{sort_by: :forwards, limit: 2})
      assert length(result) == 2
    end

    test "respects limit" do
      result = Analytics.message_performance(@sample_messages, %{limit: 2})
      assert length(result) == 2
    end

    test "includes expected fields" do
      [msg | _] = Analytics.message_performance(@sample_messages)
      assert is_integer(msg[:message_id])
      assert is_binary(msg[:author])
      assert is_binary(msg[:text_preview])
      assert is_number(msg[:score])
      assert is_integer(msg[:views])
      assert is_integer(msg[:replies])
      assert is_integer(msg[:forwards])
    end

    test "truncates long text" do
      long_msg = [%{id: 1, text: String.duplicate("x", 200), replies: [], forwards: 0, views: 0}]
      [result] = Analytics.message_performance(long_msg, %{limit: 1})
      assert byte_size(result[:text_preview]) <= 83
    end

    test "empty input returns empty list" do
      assert Analytics.message_performance([]) == []
    end
  end

  describe "generate_report/3" do
    test "returns a complete report with all sections" do
      result = Analytics.generate_report(@sample_messages, @sample_members, "weekly")

      assert result[:period] == "weekly"
      assert result[:generated_at] != nil
      assert is_map(result[:engagement])
      assert is_map(result[:growth])
      assert is_list(result[:top_messages])
      assert is_map(result[:sentiment])
      assert is_binary(result[:summary_text])
    end

    test "daily report" do
      result = Analytics.generate_report(@sample_messages, @sample_members, "daily")
      assert result[:period] == "daily"
    end

    test "monthly report" do
      result = Analytics.generate_report(@sample_messages, @sample_members, "monthly")
      assert result[:period] == "monthly"
    end

    test "summary text contains key metrics" do
      result = Analytics.generate_report(@sample_messages, @sample_members)
      text = result[:summary_text]
      assert String.contains?(text, "Engagement:")
      assert String.contains?(text, "Growth")
      assert String.contains?(text, "Top messages:")
      assert String.contains?(text, "Sentiment:")
    end

    test "empty messages returns safe report" do
      result = Analytics.generate_report([], [], "weekly")
      assert result[:engagement][:message_count] == 0
      assert is_list(result[:top_messages])
    end
  end

  describe "sentiment_trend/2" do
    test "classifies positive messages correctly" do
      positive_msgs = [
        %{id: 1, text: "Great project! Love it!"},
        %{id: 2, text: "Amazing progress today."},
        %{id: 3, text: "Excellent work team!"}
      ]

      result = Analytics.sentiment_trend(positive_msgs)
      assert result[:counts][:positive] == 3
      assert result[:counts][:negative] == 0
      assert result[:trend] == :positive
      assert result[:percentages][:positive] == 1.0
    end

    test "classifies negative messages correctly" do
      negative_msgs = [
        %{id: 1, text: "Terrible experience. Scam!"},
        %{id: 2, text: "Worst project ever. Fraud detected."},
        %{id: 3, text: "Bad decision, very disappointing."}
      ]

      result = Analytics.sentiment_trend(negative_msgs)
      assert result[:counts][:negative] == 3
      assert result[:counts][:positive] == 0
      assert result[:trend] == :negative
    end

    test "handles mixed sentiment" do
      mixed_msgs = [
        %{id: 1, text: "Great but the bug is terrible"},
        %{id: 2, text: "Solid progress"},
        %{id: 3, text: "No comment"}
      ]

      result = Analytics.sentiment_trend(mixed_msgs)
      assert result[:total_messages_analyzed] == 3
      assert result[:counts][:positive] + result[:counts][:negative] + result[:counts][:neutral] + result[:counts][:mixed] == 3
    end

    test "handles empty messages" do
      result = Analytics.sentiment_trend([])
      assert result[:total_messages_analyzed] == 0
      assert result[:trend] == :neutral
    end

    test "custom keywords" do
      msgs = [%{id: 1, text: "This is totally wobbly"}]
      result = Analytics.sentiment_trend(msgs, %{negative: ["wobbly"]})
      assert result[:counts][:negative] == 1
    end

    test "percentages sum to approximately 1" do
      result = Analytics.sentiment_trend(@sample_messages)
      total = result[:percentages][:positive] + result[:percentages][:negative] + result[:percentages][:neutral] + result[:percentages][:mixed]
      assert total >= 0.99 and total <= 1.01
    end
  end

  describe "compare_channels/1" do
    test "compares multiple channels and sorts by composite score" do
      channels = [
        %{
          name: "Channel A",
          messages: [
            %{id: 1, text: "Great update!", replies: [%{id: 1}], forwards: 5, views: 1000}
          ],
          members: [%{id: 1, username: "a_user", joined_at: "2026-06-01"}]
        },
        %{
          name: "Channel B",
          messages: [
            %{id: 1, text: "Terrible news.", replies: [], forwards: 0, views: 100}
          ],
          members: [%{id: 2, username: "b_user", joined_at: "2026-06-01"}]
        }
      ]

      result = Analytics.compare_channels(channels)
      assert length(result) == 2
      assert result == Enum.sort(result, fn a, b -> a[:composite_score] >= b[:composite_score] end)
      assert Enum.at(result, 0)[:name] == "Channel A"
    end

    test "single channel" do
      result = Analytics.compare_channels([%{name: "Solo", messages: [], members: []}])
      assert length(result) == 1
      assert result |> hd()[:name] == "Solo"
    end

    test "empty channels" do
      result = Analytics.compare_channels([])
      assert result == []
    end

    test "each channel has all expected fields" do
      channels = [%{name: "Test", messages: @sample_messages, members: @sample_members}]
      result = Analytics.compare_channels(channels)
      ch = result |> hd()

      assert is_binary(ch[:name])
      assert is_integer(ch[:message_count])
      assert is_integer(ch[:member_count])
      assert is_map(ch[:engagement])
      assert is_map(ch[:growth])
      assert is_map(ch[:sentiment])
      assert is_number(ch[:composite_score])
    end
  end

  describe "edge cases" do
    test "nil text fields handled gracefully" do
      msgs = [%{id: 1, text: nil, replies: nil, forwards: nil, views: nil}]
      result = Analytics.engagement_metrics(msgs)
      assert result[:message_count] == 0
    end

    test "missing from field" do
      msgs = [%{id: 1, text: "Hello", replies: [], forwards: 0, views: 100}]
      results = Analytics.message_performance(msgs)
      assert hd(results)[:author] == "unknown"
    end

    test "large message set performance" do
      large = Enum.map(1..500, fn i ->
        %{
          id: i,
          text: "Message #{i}",
          replies: if rem(i, 5) == 0, do: [%{id: i}, %{id: i + 1}], else: [],
          forwards: rem(i, 10),
          views: i * 100
        }
      end)

      result = Analytics.engagement_metrics(large)
      assert result[:message_count] == 500
      assert result[:engagement_score] >= 0
    end
  end
end
