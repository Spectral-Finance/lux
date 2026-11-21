defmodule Lux.Prisms.Discord.Moderation.UnbanMemberTest do
  @moduledoc """
  Test suite for the UnbanMember moderation prism (lux issue #57).
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Moderation.UnbanMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully unbans a user" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, result} =
               UnbanMember.handler(
                 %{
                   guild_id: @guild_id,
                   user_id: @user_id,
                   reason: "Appeal accepted",
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )

      assert result.unbanned == true
      assert result.guild_id == @guild_id
      assert result.user_id == @user_id
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"message" => "Unknown Ban"}))
      end)

      assert {:error, {404, "Unknown Ban"}} =
               UnbanMember.handler(
                 %{
                   guild_id: @guild_id,
                   user_id: @user_id,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end
  end
end
