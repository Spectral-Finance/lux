defmodule Lux.Prisms.Discord.Moderation.TimeoutMemberTest do
  @moduledoc """
  Test suite for the TimeoutMember moderation prism (lux issue #57).
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Moderation.TimeoutMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully times out a member" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert Map.has_key?(decoded, "communication_disabled_until")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "{}")
      end)

      assert {:ok, result} =
               TimeoutMember.handler(
                 %{
                   guild_id: @guild_id,
                   user_id: @user_id,
                   duration_seconds: 3600,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )

      assert result.timed_out == true
      assert result.guild_id == @guild_id
      assert result.user_id == @user_id
      assert result.duration_seconds == 3600
    end

    test "rejects non-positive duration" do
      assert {:error, msg} =
               TimeoutMember.handler(
                 %{guild_id: @guild_id, user_id: @user_id, duration_seconds: 0},
                 @agent_ctx
               )

      assert is_binary(msg)
    end

    test "rejects duration over 28 days" do
      assert {:error, msg} =
               TimeoutMember.handler(
                 %{guild_id: @guild_id, user_id: @user_id, duration_seconds: 2_419_201},
                 @agent_ctx
               )

      assert is_binary(msg)
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               TimeoutMember.handler(
                 %{
                   guild_id: @guild_id,
                   user_id: @user_id,
                   duration_seconds: 3600,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end
  end

  describe "iso8601_duration/1" do
    test "produces a valid future ISO-8601 timestamp" do
      {:ok, dt, _} = TimeoutMember.iso8601_duration(3600) |> DateTime.from_iso8601()
      assert DateTime.diff(dt, DateTime.utc_now(), :second) > 3000
    end
  end
end
