defmodule Lux.Lenses.Telegram.Messaging.GetUpdatesTest do
  use ExUnit.Case, async: false

  alias Lux.Lenses.Telegram.Messaging.GetUpdates
  import Mock

  @bot_token "test_bot_token"

  setup do
    Application.put_env(:lux, :req_options, plug: {Req.Test, GetUpdatesMock})
    Req.Test.verify_on_exit!()

    with_mock Lux.Config, [:passthrough], telegram_bot_token: fn -> @bot_token end do
      :ok
    end
    :ok
  end

  test "returns updates successfully" do
    Req.Test.stub(GetUpdatesMock, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/bottest_bot_token/getUpdates"
      assert conn.query_string == "offset=123"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "ok" => true,
        "result" => [
          %{
            "update_id" => 123,
            "message" => %{
              "message_id" => 1,
              "text" => "hello"
            }
          }
        ]
      }))
    end)

    with_mock Lux.Config, [:passthrough], telegram_bot_token: fn -> @bot_token end do
      {:ok, updates} = GetUpdates.focus(%{offset: 123})
      assert length(updates) == 1
      assert hd(updates)["update_id"] == 123
    end
  end

  test "handles error response" do
    Req.Test.stub(GetUpdatesMock, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "ok" => false,
        "error_code" => 401,
        "description" => "Unauthorized"
      }))
    end)

    with_mock Lux.Config, [:passthrough], telegram_bot_token: fn -> @bot_token end do
      {:error, error} = GetUpdates.focus(%{})
      assert error["error_code"] == 401
    end
  end
end
