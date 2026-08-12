defmodule Lux.Prisms.Discord.Thread.ListThreadsTest do
  @moduledoc """
  Test suite for ListThreads prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Thread.ListThreads

  @channel_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully lists threads" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/threads"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "threads" => [%{
            "id" => "111111111111111111",
            "name" => "Thread 1",
            "archived" => false,
            "auto_archive_duration" => 60,
            "owner_id" => "987654321098765432",
            "parent_id" => @channel_id
          }]
        }))
      end)

      assert {:ok, %{
        threads: [%{
          id: "111111111111111111",
          name: "Thread 1",
          archived: false,
          auto_archive_duration: 60,
          owner_id: "987654321098765432",
          parent_id: @channel_id
        }]
      }} = ListThreads.handler(
        %{
          channel_id: @channel_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/threads"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Channel"
        }))
      end)

      assert {:error, {404, "Unknown Channel"}} = ListThreads.handler(
        %{
          channel_id: @channel_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end