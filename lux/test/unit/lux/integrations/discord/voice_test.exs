defmodule Lux.Integrations.Discord.VoiceTest do
  @moduledoc """
  Tests for the Discord Voice integration module.
  """

  use UnitAPICase, async: true

  alias Lux.Integrations.Discord.Voice

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "list_regions/1" do
    test "returns voice regions on success" do
      mock_regions = [
        %{"id" => "us-west", "name" => "US West", "optimal" => true},
        %{"id" => "us-east", "name" => "US East", "optimal" => false}
      ]

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/voice/regions"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(mock_regions))
      end)

      {:ok, regions} = Voice.list_regions(%{plug: {Req.Test, DiscordClientMock}})
      assert length(regions) == 2
    end

    test "returns error on failure" do
      Req.Test.stub(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"message" => "Internal Server Error"}))
      end)

      {:error, {500, "Internal Server Error"}} =
        Voice.list_regions(%{plug: {Req.Test, DiscordClientMock}})
    end

    test "returns error for unexpected response" do
      Req.Test.stub(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!("unexpected"))
      end)

      {:error, {:unexpected_response, _}} =
        Voice.list_regions(%{plug: {Req.Test, DiscordClientMock}})
    end
  end

  describe "update_voice_state/3" do
    test "joins a voice channel" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/guild123/voice-states/@me"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["channel_id"] == "channel456"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      {:ok, _} = Voice.update_voice_state("guild123", "channel456", %{plug: {Req.Test, DiscordClientMock}})
    end

    test "disconnects from voice channel" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["channel_id"] == nil

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      {:ok, _} = Voice.update_voice_state("guild123", nil, %{plug: {Req.Test, DiscordClientMock}})
    end

    test "passes self_mute and self_deaf options" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["self_mute"] == true
        assert decoded["self_deaf"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      {:ok, _} = Voice.update_voice_state("guild123", "channel456", %{
        self_mute: true,
        self_deaf: true,
        plug: {Req.Test, DiscordClientMock}
      })
    end

    test "returns error on failure" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      {:error, {403, "Missing Permissions"}} =
        Voice.update_voice_state("guild123", "channel456", %{plug: {Req.Test, DiscordClientMock}})
    end
  end

  describe "voice_state_update_payload/3" do
    test "builds opcode 4 payload" do
      payload = Voice.voice_state_update_payload("guild123", "channel456")
      assert payload.op == 4
      assert payload.d.guild_id == "guild123"
      assert payload.d.channel_id == "channel456"
      assert payload.d.self_mute == false
      assert payload.d.self_deaf == false
    end

    test "builds disconnect payload" do
      payload = Voice.voice_state_update_payload("guild123", nil)
      assert payload.op == 4
      assert payload.d.channel_id == nil
    end

    test "builds muted/deafened payload" do
      payload = Voice.voice_state_update_payload("guild123", "channel456", self_mute: true, self_deaf: true)
      assert payload.d.self_mute == true
      assert payload.d.self_deaf == true
    end
  end

  describe "voice_server_ping_payload/0" do
    test "builds opcode 8 payload" do
      payload = Voice.voice_server_ping_payload()
      assert payload.op == 8
      assert payload.d.token == ""
      assert payload.d.guild_id == nil
      assert payload.d.endpoint == nil
    end
  end

  describe "identify_payload/4" do
    test "builds voice identify payload" do
      payload = Voice.identify_payload("guild123", "user456", "session789", "tokenabc")
      assert payload.op == 0
      assert payload.d.server_id == "guild123"
      assert payload.d.user_id == "user456"
      assert payload.d.session_id == "session789"
      assert payload.d.token == "tokenabc"
    end
  end

  describe "resume_payload/4" do
    test "builds voice resume payload" do
      payload = Voice.resume_payload("guild123", "session789", "tokenabc", 42)
      assert payload.op == 7
      assert payload.d.server_id == "guild123"
      assert payload.d.session_id == "session789"
      assert payload.d.token == "tokenabc"
      assert payload.d.seq == 42
    end
  end

  describe "speaking_payload/3" do
    test "builds default speaking payload" do
      payload = Voice.speaking_payload()
      assert payload.op == 5
      assert payload.d.speaking == 1
      assert payload.d.delay == 0
      assert payload.d.ssrc == 0
    end

    test "builds custom speaking payload" do
      payload = Voice.speaking_payload(2, 100, 12345)
      assert payload.d.speaking == 2
      assert payload.d.delay == 100
      assert payload.d.ssrc == 12345
    end
  end

  describe "validate_status/1" do
    test "validates string statuses" do
      assert {:ok, "online"} = Voice.validate_status("online")
      assert {:ok, "dnd"} = Voice.validate_status("dnd")
      assert {:ok, "idle"} = Voice.validate_status("idle")
      assert {:ok, "invisible"} = Voice.validate_status("invisible")
      assert {:ok, "offline"} = Voice.validate_status("offline")
    end

    test "validates atom statuses" do
      assert {:ok, "online"} = Voice.validate_status(:online)
      assert {:ok, "dnd"} = Voice.validate_status(:dnd)
    end

    test "rejects invalid statuses" do
      assert {:error, :invalid_status} = Voice.validate_status("invalid")
      assert {:error, :invalid_status} = Voice.validate_status(:invalid)
      assert {:error, :invalid_status} = Voice.validate_status(123)
    end
  end

  describe "gateway_opcodes/0" do
    test "returns all gateway opcodes" do
      opcodes = Voice.gateway_opcodes()
      assert opcodes[:identify] == 0
      assert opcodes[:select_protocol] == 1
      assert opcodes[:ready] == 2
      assert opcodes[:heartbeat] == 3
      assert opcodes[:session_description] == 4
      assert opcodes[:speaking] == 5
      assert opcodes[:heartbeat_ack] == 6
      assert opcodes[:resume] == 7
      assert opcodes[:hello] == 8
      assert opcodes[:resumed] == 9
      assert opcodes[:client_disconnect] == 13
    end
  end
end
