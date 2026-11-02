defmodule Lux.Lenses.Telegram.Updates.GetUpdatesTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Telegram.Updates.GetUpdates

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "retrieves updates via long polling lens" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.contains?(conn.request_path, "/getUpdates")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => [
              %{
                "update_id" => 100,
                "message" => %{
                  "message_id" => 1,
                  "text" => "Hello"
                }
              }
            ]
          })
        )
      end)

      assert {:ok, updates} = GetUpdates.focus(%{}, %{})
      assert length(updates) == 1
      assert hd(updates)["update_id"] == 100
    end
  end
end
