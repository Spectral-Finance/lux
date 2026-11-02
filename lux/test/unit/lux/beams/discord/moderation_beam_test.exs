defmodule Lux.Beams.Discord.ModerationBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Discord.ModerationBeam

  describe "run/2" do
    test "executes full moderation pipeline when content is flagged" do
      plug = fn conn ->
        cond do
          conn.method == "DELETE" and String.contains?(conn.request_path, "/messages/msg_bad") ->
            conn |> Plug.Conn.resp(204, "")

          conn.method == "PATCH" and String.contains?(conn.request_path, "/members/user_bad") ->
            conn
            |> Plug.Conn.put_resp_header("content-type", "application/json")
            |> Plug.Conn.resp(200, Jason.encode!(%{"user" => %{"id" => "user_bad"}}))

          conn.method == "POST" and String.contains?(conn.request_path, "/channels/log_chan/messages") ->
            conn
            |> Plug.Conn.put_resp_header("content-type", "application/json")
            |> Plug.Conn.resp(200, Jason.encode!(%{"id" => "log_msg_1"}))

          true ->
            conn |> Plug.Conn.resp(200, "{}")
        end
      end

      {:ok, result} =
        ModerationBeam.run(%{
          guild_id: "g_100",
          channel_id: "chan_general",
          message_id: "msg_bad",
          user_id: "user_bad",
          content: "Get your free nitro gift immediately!",
          prohibited_words: ["free nitro", "airdrop scam"],
          log_channel_id: "log_chan",
          timeout_seconds: 300,
          plug: plug
        })

      assert result.flagged == true
      assert result.deleted == true
      assert result.timed_out == true
      assert result.audit_logged == true
    end

    test "skips moderation action when content is clean" do
      {:ok, result} =
        ModerationBeam.run(%{
          guild_id: "g_100",
          channel_id: "chan_general",
          message_id: "msg_clean",
          user_id: "user_clean",
          content: "Hello everyone, how are you today?",
          prohibited_words: ["free nitro", "scam"]
        })

      assert result.flagged == false
      assert result.deleted == false
      assert result.timed_out == false
    end
  end
end
