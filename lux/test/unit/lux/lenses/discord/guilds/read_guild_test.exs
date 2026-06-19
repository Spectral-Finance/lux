defmodule Lux.Lenses.Discord.Guilds.ReadGuildTest do
  @moduledoc """
  Test suite for ReadGuild lens.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Guilds.ReadGuild

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully reads guild" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "id" => @guild_id,
            "name" => "Guild One",
            "icon" => "iconhash",
            "description" => "A description",
            "owner_id" => "111222333444",
            "approximate_member_count" => 150,
            "approximate_presence_count" => 30
          })
        )
      end)

      assert {:ok, guild} = ReadGuild.focus(%{guild_id: @guild_id}, %{})
      assert guild.id == @guild_id
      assert guild.name == "Guild One"
      assert guild.approximate_member_count == 150
    end

    test "handles error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"message" => "Unknown Guild"}))
      end)

      assert {:error, %{"message" => "Unknown Guild"}} = ReadGuild.focus(%{guild_id: @guild_id}, %{})
    end
  end
end
