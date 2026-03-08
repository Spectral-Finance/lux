defmodule Lux.Signals.Discord.SignalsTest do
  use ExUnit.Case, async: true

  alias Lux.Signals.Discord.{MessageSignal, InteractionSignal, PresenceSignal, Pipeline}

  # === MessageSignal ===

  test "create message signal" do
    {:ok, sig} = MessageSignal.new(%{content: "hello", channel_id: "123"})
    assert sig.content == "hello"
    assert sig.channel_id == "123"
    assert sig.attachments == []
    assert sig.embeds == []
    assert %DateTime{} = sig.timestamp
  end

  test "message signal requires content" do
    assert {:error, :content_required} = MessageSignal.new(%{})
  end

  test "message signal with string keys" do
    {:ok, sig} = MessageSignal.new(%{"content" => "test", "channel_id" => "99"})
    assert sig.content == "test"
    assert sig.channel_id == "99"
  end

  test "message with all fields" do
    {:ok, sig} = MessageSignal.new(%{
      content: "hi", channel_id: "1", guild_id: "2",
      attachments: [%{url: "http://img.png"}],
      embeds: [%{title: "embed"}],
      components: [%{type: 1}],
      metadata: %{custom: true}
    })
    assert length(sig.attachments) == 1
    assert length(sig.embeds) == 1
    assert length(sig.components) == 1
    assert sig.metadata.custom
  end

  test "message to discord" do
    {:ok, sig} = MessageSignal.new(%{content: "hi", channel_id: "1", embeds: [%{title: "t"}]})
    discord = MessageSignal.to_discord(sig)
    assert discord["content"] == "hi"
    assert discord["channel_id"] == "1"
    assert length(discord["embeds"]) == 1
  end

  test "message from discord" do
    {:ok, sig} = MessageSignal.from_discord(%{
      "content" => "test", "channel_id" => "456",
      "author" => %{"id" => "1", "username" => "user"},
      "guild_id" => "789", "attachments" => [%{"url" => "x"}]
    })
    assert sig.content == "test"
    assert sig.author["id"] == "1"
    assert sig.guild_id == "789"
    assert length(sig.attachments) == 1
  end

  test "validate valid message" do
    {:ok, sig} = MessageSignal.new(%{content: "ok"})
    assert :ok = MessageSignal.validate(sig)
  end

  test "validate empty content" do
    sig = %MessageSignal{content: ""}
    assert {:error, :invalid_content} = MessageSignal.validate(sig)
  end

  test "roundtrip message" do
    {:ok, original} = MessageSignal.new(%{content: "roundtrip", channel_id: "42"})
    discord = MessageSignal.to_discord(original)
    {:ok, restored} = MessageSignal.from_discord(discord)
    assert restored.content == original.content
    assert restored.channel_id == original.channel_id
  end

  # === InteractionSignal ===

  test "create slash command" do
    {:ok, sig} = InteractionSignal.new(%{type: :slash_command, name: "/ping", data: %{arg: "val"}})
    assert sig.type == :slash_command
    assert sig.name == "/ping"
    assert sig.data.arg == "val"
  end

  test "create button interaction" do
    {:ok, sig} = InteractionSignal.new(%{type: :button, name: "confirm_btn"})
    assert sig.type == :button
  end

  test "create select menu" do
    {:ok, sig} = InteractionSignal.new(%{type: :select_menu, name: "role_select"})
    assert sig.type == :select_menu
  end

  test "create modal" do
    {:ok, sig} = InteractionSignal.new(%{type: :modal, name: "feedback_modal"})
    assert sig.type == :modal
  end

  test "create context menu" do
    {:ok, sig} = InteractionSignal.new(%{type: :context_menu, name: "user_info"})
    assert sig.type == :context_menu
  end

  test "reject invalid interaction type" do
    assert {:error, :invalid_interaction_type} = InteractionSignal.new(%{type: :invalid})
  end

  test "interaction to discord" do
    {:ok, sig} = InteractionSignal.new(%{type: :slash_command, name: "ping", channel_id: "1", guild_id: "2"})
    discord = InteractionSignal.to_discord(sig)
    assert discord["type"] == 2
    assert discord["data"]["name"] == "ping"
  end

  test "interaction from discord" do
    {:ok, sig} = InteractionSignal.from_discord(%{
      "type" => 2, "data" => %{"name" => "help", "options" => [%{"name" => "topic"}]},
      "channel_id" => "1", "guild_id" => "2",
      "member" => %{"user" => %{"id" => "99"}}, "token" => "abc"
    })
    assert sig.type == :slash_command
    assert sig.name == "help"
    assert sig.token == "abc"
  end

  test "interaction types list" do
    types = InteractionSignal.interaction_types()
    assert :slash_command in types
    assert :modal in types
    assert length(types) == 5
  end

  # === PresenceSignal ===

  test "create presence" do
    {:ok, sig} = PresenceSignal.new(%{user_id: "123", status: :online, guild_id: "456"})
    assert sig.status == :online
    assert sig.user_id == "123"
    assert sig.activities == []
  end

  test "presence with activities" do
    {:ok, sig} = PresenceSignal.new(%{user_id: "1", status: :dnd, activities: [%{name: "Playing Game", type: 0}]})
    assert length(sig.activities) == 1
  end

  test "presence defaults to offline" do
    {:ok, sig} = PresenceSignal.new(%{user_id: "1"})
    assert sig.status == :offline
  end

  test "reject invalid presence status" do
    assert {:error, :invalid_status} = PresenceSignal.new(%{user_id: "1", status: :away})
  end

  test "all valid statuses" do
    for status <- [:online, :idle, :dnd, :offline, :invisible] do
      {:ok, sig} = PresenceSignal.new(%{user_id: "1", status: status})
      assert sig.status == status
    end
  end

  test "presence to discord" do
    {:ok, sig} = PresenceSignal.new(%{user_id: "42", status: :idle, guild_id: "99"})
    discord = PresenceSignal.to_discord(sig)
    assert discord["user"]["id"] == "42"
    assert discord["status"] == "idle"
    assert discord["guild_id"] == "99"
  end

  test "presence from discord" do
    {:ok, sig} = PresenceSignal.from_discord(%{
      "user" => %{"id" => "77"}, "status" => "online",
      "guild_id" => "88", "activities" => [%{"name" => "VS Code", "type" => 0, "state" => "editing"}],
      "client_status" => %{"desktop" => "online"}
    })
    assert sig.user_id == "77"
    assert sig.status == :online
    assert length(sig.activities) == 1
    assert sig.client_status["desktop"] == "online"
  end

  test "valid statuses list" do
    statuses = PresenceSignal.valid_statuses()
    assert length(statuses) == 5
    assert :online in statuses
  end

  # === Pipeline ===

  test "classify message" do
    assert {:ok, :message} = Pipeline.classify(%{"content" => "hi"})
    assert {:ok, :message} = Pipeline.classify(%{content: "hi"})
  end

  test "classify interaction" do
    assert {:ok, :interaction} = Pipeline.classify(%{"type" => 2})
  end

  test "classify presence" do
    assert {:ok, :presence} = Pipeline.classify(%{"status" => "online"})
    assert {:ok, :presence} = Pipeline.classify(%{status: :online})
  end

  test "classify unknown" do
    assert {:error, :unknown_signal} = Pipeline.classify(%{"random" => true})
  end

  test "parse message payload" do
    {:ok, sig} = Pipeline.parse(%{"content" => "parsed"})
    assert %MessageSignal{} = sig
    assert sig.content == "parsed"
  end

  test "parse interaction payload" do
    {:ok, sig} = Pipeline.parse(%{"type" => 2, "data" => %{"name" => "test"}})
    assert %InteractionSignal{} = sig
  end

  test "parse presence payload" do
    {:ok, sig} = Pipeline.parse(%{"status" => "idle", "user" => %{"id" => "1"}})
    assert %PresenceSignal{} = sig
  end

  test "process empty pipeline" do
    {:ok, sig} = MessageSignal.new(%{content: "test"})
    assert {:ok, ^sig} = Pipeline.process(sig, [])
  end

  test "process pipeline with steps" do
    {:ok, sig} = MessageSignal.new(%{content: "hello"})
    upper = fn s -> {:ok, %{s | content: String.upcase(s.content)}} end
    {:ok, result} = Pipeline.process(sig, [upper])
    assert result.content == "HELLO"
  end

  test "process pipeline halts on error" do
    {:ok, sig} = MessageSignal.new(%{content: "test"})
    fail = fn _s -> {:error, :processing_failed} end
    never = fn s -> {:ok, %{s | content: "should not reach"}} end
    assert {:error, :processing_failed} = Pipeline.process(sig, [fail, never])
  end

  test "process multi-step pipeline" do
    {:ok, sig} = MessageSignal.new(%{content: "hello world"})
    step1 = fn s -> {:ok, %{s | content: String.upcase(s.content)}} end
    step2 = fn s -> {:ok, %{s | content: String.replace(s.content, " ", "_")}} end
    {:ok, result} = Pipeline.process(sig, [step1, step2])
    assert result.content == "HELLO_WORLD"
  end
end
