defmodule Lux.Lenses.Discord.Guilds.ListGuildsTest do
  @moduledoc """
  Test suite for ListGuilds lens.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Guilds.ListGuilds

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists guilds" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/users/@me/guilds"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!([
            %{
              "id" => "123456789012345678",
              "name" => "Guild One",
              "icon" => "iconhash",
              "owner" => true,
              "permissions" => "104320577",
              "features" => ["COMMUNITY"]
            }
          ])
        )
      end)

      assert {:ok, guilds} = ListGuilds.focus(%{}, %{})
      assert length(guilds) == 1
      [guild] = guilds
      assert guild.id == "123456789012345678"
      assert guild.name == "Guild One"
      assert guild.owner == true
    end

    test "handles error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/users/@me/guilds"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"message" => "401: Unauthorized"}))
      end)

      assert {:error, %{"message" => "401: Unauthorized"}} = ListGuilds.focus(%{}, %{})
    end
  end
end
