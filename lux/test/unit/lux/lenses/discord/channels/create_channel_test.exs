defmodule Lux.Lenses.Discord.Channels.CreateChannelTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Discord.Channels.CreateChannel

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "creates channel in guild" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/:guild_id/channels"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["name"] == "general-ai"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          201,
          Jason.encode!(%{
            "id" => "999888777666555444",
            "guild_id" => @guild_id,
            "name" => decoded["name"],
            "type" => 0,
            "topic" => "General AI Discussion",
            "rate_limit_per_user" => 5
          })
        )
      end)

      assert {:ok, result} =
               CreateChannel.focus(
                 %{
                   "guild_id" => @guild_id,
                   "name" => "general-ai",
                   "topic" => "General AI Discussion",
                   "rate_limit_per_user" => 5
                 },
                 %{}
               )

      assert result.id == "999888777666555444"
      assert result.name == "general-ai"
      assert result.rate_limit_per_user == 5
    end
  end
end
