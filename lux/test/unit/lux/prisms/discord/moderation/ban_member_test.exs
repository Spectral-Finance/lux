defmodule Lux.Prisms.Discord.Moderation.BanMemberTest do
  @moduledoc """
  Test suite for the BanMember moderation prism (lux issue #57).
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Moderation.BanMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully bans a member" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, result} =
               BanMember.handler(
                 %{
                   guild_id: @guild_id,
                   user_id: @user_id,
                   reason: "Violation",
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )

      assert result.banned == true
      assert result.guild_id == @guild_id
      assert result.user_id == @user_id
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               BanMember.handler(
                 %{
                   guild_id: @guild_id,
                   user_id: @user_id,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end

    test "rejects missing user_id" do
      assert {:error, msg} = BanMember.handler(%{guild_id: @guild_id}, @agent_ctx)
      assert is_binary(msg)
    end
  end
end