defmodule Lux.Prisms.Discord.Thread.CreateThreadTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Thread.CreateThread

  @channel_id "123456789012345678"
  @message_id "987654321098765432"
  @thread_name "Test Thread"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates a thread from a message" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}/threads"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{
          "name" => @thread_name,
          "auto_archive_duration" => 1440,
          "rate_limit_per_user" => 0
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "111111111111111111",
          "name" => @thread_name
        }))
      end)

      assert {:ok, %{
        created: true,
        thread_id: "111111111111111111",
        name: @thread_name,
        channel_id: @channel_id
      }} = CreateThread.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id,
          name: @thread_name,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully creates a thread without a message" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/threads"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{
          "name" => @thread_name,
          "auto_archive_duration" => 60,
          "rate_limit_per_user" => 10
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "111111111111111111",
          "name" => @thread_name
        }))
      end)

      assert {:ok, %{
        created: true,
        thread_id: "111111111111111111",
        name: @thread_name,
        channel_id: @channel_id
      }} = CreateThread.handler(
        %{
          channel_id: @channel_id,
          name: @thread_name,
          auto_archive_duration: 60,
          rate_limit_per_user: 10,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/threads"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = CreateThread.handler(
        %{
          channel_id: @channel_id,
          name: @thread_name,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = CreateThread.view()
      assert prism.input_schema.required == ["channel_id", "name"]
      assert Map.has_key?(prism.input_schema.properties, :channel_id)
      assert Map.has_key?(prism.input_schema.properties, :message_id)
      assert Map.has_key?(prism.input_schema.properties, :name)
      assert Map.has_key?(prism.input_schema.properties, :auto_archive_duration)
      assert Map.has_key?(prism.input_schema.properties, :rate_limit_per_user)
    end

    test "validates output schema" do
      prism = CreateThread.view()
      assert prism.output_schema.required == ["created"]
      assert Map.has_key?(prism.output_schema.properties, :created)
      assert Map.has_key?(prism.output_schema.properties, :thread_id)
      assert Map.has_key?(prism.output_schema.properties, :name)
      assert Map.has_key?(prism.output_schema.properties, :channel_id)
    end
  end
end
