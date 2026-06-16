defmodule Lux.Lenses.Telegram.ListUpdatesTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Telegram.ListUpdates

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists updates from Telegram" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/bottest_telegram_bot_token/getUpdates"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{
              "update_id" => 1234567,
              "message" => %{
                "message_id" => 1,
                "text" => "hello"
              }
            }
          ]
        }))
      end)

      assert {:ok, [update]} = ListUpdates.focus()
      assert update["update_id"] == 1234567
      assert get_in(update, ["message", "text"]) == "hello"
    end

    test "handles Telegram API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/bottest_telegram_bot_token/getUpdates"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Unauthorized"
        }))
      end)

      assert {:error, "Unauthorized"} = ListUpdates.focus()
    end

    test "handles unexpected response format" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/bottest_telegram_bot_token/getUpdates"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "weird" => "format"
        }))
      end)

      assert {:error, "Unexpected response format: " <> _} = ListUpdates.focus()
    end
  end
end
