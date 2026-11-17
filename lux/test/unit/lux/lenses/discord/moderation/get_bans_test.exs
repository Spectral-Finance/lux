defmodule Lux.Lenses.Discord.Moderation.GetBansTest do
  @moduledoc """
  Test suite for the GetBans module.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Moderation.GetBans

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches bans" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/bans"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "reason" => "Spam",
            "user" => %{
              "id" => "111111111111111111",
              "username" => "spammer"
            }
          },
          %{
            "reason" => nil,
            "user" => %{
              "id" => "222222222222222222",
              "username" => "troll"
            }
          }
        ]))
      end)

      assert {:ok, bans} = GetBans.focus(%{guild_id: @guild_id}, %{})
      assert length(bans) == 2
      [first, second] = bans
      assert first.user_id == "111111111111111111"
      assert first.username == "spammer"
      assert first.reason == "Spam"
      assert second.reason == nil
    end

    test "handles empty ban list" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = GetBans.focus(%{guild_id: @guild_id}, %{})
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} =
        GetBans.focus(%{guild_id: @guild_id}, %{})
    end
  end
end
