defmodule Lux.Prisms.Discord.ModerationPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Discord.ModerationPrism

  describe "handler/2 actions" do
    test "timeouts member via prism" do
      plug = fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/guilds/g123/members/u456"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"user" => %{"id" => "u456"}}))
      end

      {:ok, res} =
        ModerationPrism.run(%{
          action: "timeout_member",
          payload: %{
            guild_id: "g123",
            user_id: "u456",
            duration_seconds: 600,
            plug: plug
          }
        })

      assert res.action == "timeout_member"
      assert res.result.timed_out == true
      assert is_binary(res.result.until)
    end

    test "filters content against prohibited words" do
      {:ok, res} =
        ModerationPrism.run(%{
          action: "filter_content",
          payload: %{
            content: "Check this free scam link now!",
            prohibited_words: ["scam", "phishing", "free nitro"]
          }
        })

      assert res.action == "filter_content"
      assert res.result.flagged == true
      assert res.result.matches == ["scam"]
    end
  end
end
