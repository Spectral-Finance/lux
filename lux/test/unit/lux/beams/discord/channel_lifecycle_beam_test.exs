defmodule Lux.Beams.Discord.ChannelLifecycleBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Discord.ChannelLifecycleBeam

  describe "run/2" do
    test "provisions channel, configures permissions, and announces" do
      plug = fn conn ->
        cond do
          conn.method == "POST" and String.contains?(conn.request_path, "/guilds/g_500/channels") ->
            conn
            |> Plug.Conn.put_resp_header("content-type", "application/json")
            |> Plug.Conn.resp(201, Jason.encode!(%{"id" => "chan_new_123", "name" => "announcements"}))

          conn.method == "PUT" and String.contains?(conn.request_path, "/permissions/role_vip") ->
            conn |> Plug.Conn.resp(204, "")

          conn.method == "POST" and String.contains?(conn.request_path, "/messages") ->
            conn
            |> Plug.Conn.put_resp_header("content-type", "application/json")
            |> Plug.Conn.resp(200, Jason.encode!(%{"id" => "msg_welcome_1"}))

          true ->
            conn |> Plug.Conn.resp(200, "{}")
        end
      end

      {:ok, result} =
        ChannelLifecycleBeam.run(%{
          guild_id: "g_500",
          name: "announcements",
          role_id: "role_vip",
          allow: "1024",
          welcome_message: "Welcome to the new announcements channel!",
          plug: plug
        })

      assert result.channel_id == "chan_new_123"
      assert result.channel_name == "announcements"
      assert result.permissions_configured == true
      assert result.announced == true
    end
  end
end
