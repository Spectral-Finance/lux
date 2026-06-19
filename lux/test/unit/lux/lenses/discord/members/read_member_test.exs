defmodule Lux.Lenses.Discord.Members.ReadMemberTest do
  @moduledoc """
  Test suite for ReadMember lens.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Members.ReadMember

  @guild_id "123456789012345678"
  @user_id "111222333444555666"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully reads member" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "user" => %{
              "id" => @user_id,
              "username" => "TestUser",
              "discriminator" => "0000",
              "avatar" => "avatarhash"
            },
            "nick" => "Nickname",
            "roles" => ["role1"],
            "joined_at" => "2026-06-01T00:00:00.000Z",
            "premium_since" => nil,
            "deaf" => false,
            "mute" => false,
            "pending" => false
          })
        )
      end)

      assert {:ok, member} = ReadMember.focus(%{guild_id: @guild_id, user_id: @user_id}, %{})
      assert member.user.id == @user_id
      assert member.user.username == "TestUser"
      assert member.nick == "Nickname"
    end

    test "handles error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"message" => "Unknown Member"}))
      end)

      assert {:error, %{"message" => "Unknown Member"}} =
               ReadMember.focus(%{guild_id: @guild_id, user_id: @user_id}, %{})
    end
  end
end
