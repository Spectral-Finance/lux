defmodule Lux.Lenses.Discord.Members.ListMembersTest do
  @moduledoc """
  Test suite for ListMembers lens.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Members.ListMembers

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists members" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!([
            %{
              "user" => %{
                "id" => "111222333444",
                "username" => "TestUser",
                "discriminator" => "0000",
                "avatar" => "avatarhash"
              },
              "nick" => "Nickname",
              "roles" => ["role1"],
              "joined_at" => "2026-06-01T00:00:00.000Z",
              "deaf" => false,
              "mute" => false
            }
          ])
        )
      end)

      assert {:ok, members} = ListMembers.focus(%{guild_id: @guild_id}, %{})
      assert length(members) == 1
      [member] = members
      assert member.user.id == "111222333444"
      assert member.user.username == "TestUser"
      assert member.nick == "Nickname"
    end

    test "handles error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} =
               ListMembers.focus(%{guild_id: @guild_id}, %{})
    end
  end
end
