defmodule Lux.Prisms.Discord.AdvancedTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Discord.{VoiceChannel, RichPresence, WebhookManager, ServerAnalytics}

  defp mock_plug(status, body) do
    {Req.Test, __MODULE__.Stub}
    |> tap(fn _ ->
      Req.Test.stub(__MODULE__.Stub, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(status, Jason.encode!(body))
      end)
    end)
  end

  defp opts(status, body) do
    %{token: "test", plug: mock_plug(status, body)}
  end

  # === VoiceChannel ===

  test "join voice" do
    {:ok, _} = VoiceChannel.join("g1", "vc1", opts(200, %{"channel_id" => "vc1"}))
  end

  test "join voice muted" do
    {:ok, _} = VoiceChannel.join("g1", "vc1", Map.merge(opts(200, %{}), %{mute: true, deaf: true}))
  end

  test "leave voice" do
    {:ok, _} = VoiceChannel.leave("g1", opts(200, %{}))
  end

  test "get regions" do
    regions = [%{"id" => "us-east", "name" => "US East"}]
    {:ok, body} = VoiceChannel.get_regions(opts(200, regions))
    assert length(body) == 1
  end

  test "voice unauthorized" do
    assert {:error, :invalid_token} = VoiceChannel.join("g1", "vc1", opts(401, %{}))
  end

  # === RichPresence ===

  test "create presence" do
    {:ok, rp} = RichPresence.new(%{name: "Testing", type: :playing, state: "In Game"})
    assert rp.name == "Testing"
    assert rp.type == 0
    assert rp.state == "In Game"
  end

  test "create streaming presence" do
    {:ok, rp} = RichPresence.new(%{name: "Live", type: :streaming, url: "https://twitch.tv/test"})
    assert rp.type == 1
    assert rp.url == "https://twitch.tv/test"
  end

  test "all activity types" do
    types = RichPresence.activity_types()
    assert types.playing == 0
    assert types.streaming == 1
    assert types.listening == 2
    assert types.watching == 3
    assert types.custom == 4
    assert types.competing == 5
  end

  test "to_payload filters nils" do
    {:ok, rp} = RichPresence.new(%{name: "Test", type: :playing})
    payload = RichPresence.to_payload(rp)
    assert payload["name"] == "Test"
    refute Map.has_key?(payload, "state")
    refute Map.has_key?(payload, "url")
  end

  test "to_payload with all fields" do
    {:ok, rp} = RichPresence.new(%{
      name: "Game", type: :playing, state: "Ranked",
      details: "Level 5", assets: %{large_image: "icon"}
    })
    payload = RichPresence.to_payload(rp)
    assert payload["details"] == "Level 5"
    assert payload["assets"] == %{large_image: "icon"}
  end

  # === WebhookManager ===

  test "create webhook" do
    {:ok, body} = WebhookManager.create("ch1", "My Hook", opts(200, %{"id" => "wh1", "name" => "My Hook"}))
    assert body["name"] == "My Hook"
  end

  test "delete webhook" do
    {:ok, _} = WebhookManager.delete("wh1", opts(204, %{}))
  end

  test "execute webhook" do
    {:ok, result} = WebhookManager.execute("wh1", "token123", %{content: "Hello from webhook!"})
    assert result.body.content == "Hello from webhook!"
    assert result.url =~ "wh1"
    assert result.url =~ "token123"
  end

  test "list webhooks" do
    hooks = [%{"id" => "wh1"}, %{"id" => "wh2"}]
    {:ok, body} = WebhookManager.list("ch1", opts(200, hooks))
    assert length(body) == 2
  end

  test "webhook unauthorized" do
    assert {:error, :invalid_token} = WebhookManager.create("ch1", "x", opts(401, %{}))
  end

  # === ServerAnalytics ===

  test "analyze activity by hour" do
    messages = [
      %{hour: 10, channel_id: "ch1"}, %{hour: 10, channel_id: "ch1"},
      %{hour: 14, channel_id: "ch2"}, %{hour: 22, channel_id: "ch1"}
    ]
    {:ok, result} = ServerAnalytics.analyze_activity(messages)
    assert result.total == 4
    assert result.by_hour[10] == 2
    assert result.by_hour[14] == 1
    assert result.by_channel["ch1"] == 3
  end

  test "analyze empty messages" do
    {:ok, result} = ServerAnalytics.analyze_activity([])
    assert result.total == 0
  end

  test "member stats" do
    members = [
      %{id: "1", bot: false}, %{id: "2", bot: false},
      %{id: "3", bot: true}
    ]
    {:ok, stats} = ServerAnalytics.member_stats(members)
    assert stats.total == 3
    assert stats.humans == 2
    assert stats.bots == 1
  end

  test "member stats all bots" do
    {:ok, stats} = ServerAnalytics.member_stats([%{bot: true}, %{bot: true}])
    assert stats.humans == 0
    assert stats.bots == 2
  end

  test "growth rate" do
    {:ok, g} = ServerAnalytics.growth_rate([100, 120, 150])
    assert g.rate == 50.0
    assert g.from == 100
    assert g.to == 150
  end

  test "growth rate negative" do
    {:ok, g} = ServerAnalytics.growth_rate([200, 150])
    assert g.rate == -25.0
  end

  test "growth rate insufficient data" do
    assert {:error, :insufficient_data} = ServerAnalytics.growth_rate([100])
    assert {:error, :insufficient_data} = ServerAnalytics.growth_rate([])
  end
end
