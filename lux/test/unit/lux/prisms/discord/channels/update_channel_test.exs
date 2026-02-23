defmodule Lux.Prisms.Discord.Channels.UpdateChannelTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Channels.UpdateChannel

  @channel_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully updates channel name and topic" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["name"] == "new-name"
        assert decoded["topic"] == "Updated topic"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @channel_id}))
      end)

      assert {:ok, %{updated: true, channel_id: @channel_id}} =
        UpdateChannel.handler(
          %{channel_id: @channel_id, name: "new-name", topic: "Updated topic", plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "successfully archives a thread" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["archived"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @channel_id}))
      end)

      assert {:ok, %{updated: true, channel_id: @channel_id}} =
        UpdateChannel.handler(
          %{channel_id: @channel_id, archived: true, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "returns error when no updatable fields provided" do
      assert {:error, "No updatable fields provided"} =
        UpdateChannel.handler(%{channel_id: @channel_id}, @agent_ctx)
    end

    test "returns error when channel_id is missing" do
      assert {:error, "Missing or invalid channel_id"} =
        UpdateChannel.handler(%{name: "new-name"}, @agent_ctx)
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
        UpdateChannel.handler(
          %{channel_id: @channel_id, name: "new-name", plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end
  end
end
