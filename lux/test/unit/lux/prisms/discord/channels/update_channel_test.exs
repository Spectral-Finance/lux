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
    test "updates mutable channel settings" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"

        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(body) == %{
                 "name" => "ops-room",
                 "topic" => "Operations updates",
                 "rate_limit_per_user" => 5
               }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "id" => @channel_id,
            "name" => "ops-room",
            "topic" => "Operations updates",
            "type" => 0,
            "guild_id" => "222222222222222222"
          })
        )
      end)

      assert {:ok,
              %{
                updated: true,
                channel_id: @channel_id,
                name: "ops-room",
                topic: "Operations updates",
                type: 0
              }} =
               UpdateChannel.handler(
                 %{
                   channel_id: @channel_id,
                   name: "ops-room",
                   topic: "Operations updates",
                   rate_limit_per_user: 5
                 },
                 @agent_ctx
               )
    end

    test "handles Discord API errors" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               UpdateChannel.handler(
                 %{channel_id: @channel_id, name: "ops-room"},
                 @agent_ctx
               )
    end
  end
end
