defmodule Lux.Lenses.Telegram.Bot.GetMeTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Telegram.Bot.GetMe

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "fetches bot user info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.contains?(conn.request_path, "/getMe")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "id" => 123456789,
              "is_bot" => true,
              "first_name" => "LuxBot",
              "username" => "lux_official_bot"
            }
          })
        )
      end)

      assert {:ok, result} = GetMe.focus(%{}, %{})
      assert result["id"] == 123456789
      assert result["username"] == "lux_official_bot"
    end
  end
end
