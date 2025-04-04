defmodule Lux.Prisms.Discord.Channels.EditChannelTest do
  @moduledoc """
  Tests for the EditChannel prism which modifies Discord channel settings.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Channels.EditChannel

  @channel_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully edits a channel with all fields" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{
          "name" => "new-channel-name",
          "topic" => "New channel topic",
          "nsfw" => true
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @channel_id,
          "name" => "new-channel-name",
          "topic" => "New channel topic"
        }))
      end)

      assert {:ok, %{
        edited: true,
        channel_id: @channel_id,
        name: "new-channel-name",
        topic: "New channel topic"
      }} = EditChannel.handler(
        %{
          channel_id: @channel_id,
          name: "new-channel-name",
          topic: "New channel topic",
          nsfw: true,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully edits a channel with minimal fields" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{
          "name" => "new-channel-name"
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @channel_id,
          "name" => "new-channel-name",
          "topic" => nil
        }))
      end)

      assert {:ok, %{
        edited: true,
        channel_id: @channel_id,
        name: "new-channel-name",
        topic: nil
      }} = EditChannel.handler(
        %{
          channel_id: @channel_id,
          name: "new-channel-name",
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles missing required channel_id" do
      assert {:error, "Missing or invalid channel_id"} = EditChannel.handler(
        %{
          name: "new-channel-name"
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = EditChannel.handler(
        %{
          channel_id: @channel_id,
          name: "new-channel-name",
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = EditChannel.view()
      assert prism.input_schema.required == ["channel_id"]
      assert Map.has_key?(prism.input_schema.properties, :channel_id)
      assert Map.has_key?(prism.input_schema.properties, :name)
      assert Map.has_key?(prism.input_schema.properties, :topic)
      assert Map.has_key?(prism.input_schema.properties, :nsfw)
    end

    test "validates output schema" do
      prism = EditChannel.view()
      assert prism.output_schema.required == ["edited"]
      assert Map.has_key?(prism.output_schema.properties, :edited)
      assert Map.has_key?(prism.output_schema.properties, :channel_id)
      assert Map.has_key?(prism.output_schema.properties, :name)
      assert Map.has_key?(prism.output_schema.properties, :topic)
    end

    test "validates channel_id format" do
      invalid_cases = [
        "",
        "invalid",
        "123",  # too short
        "12345678901234567890123"  # too long
      ]

      for invalid_id <- invalid_cases do
        assert {:error, "Missing or invalid channel_id"} = EditChannel.handler(
          %{
            channel_id: invalid_id,
            name: "new-channel-name"
          },
          @agent_ctx
        )
      end
    end
  end
end
