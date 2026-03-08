defmodule Lux.Integrations.Telegram.ClientTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Client

  setup do
    Req.Test.stub(Lux.Telegram.MockOk, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => %{"id" => 123, "first_name" => "TestBot"}})
    end)

    Req.Test.stub(Lux.Telegram.MockError, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{"ok" => false, "error_code" => 400, "description" => "Bad Request"})
    end)

    :ok
  end

  test "successful request" do
    assert {:ok, %{"id" => 123}} =
             Client.request("getMe", %{}, token: "123:abc", plug: {Req.Test, Lux.Telegram.MockOk})
  end

  test "error response" do
    assert {:error, %{code: 400, description: "Bad Request"}} =
             Client.request("getMe", %{}, token: "123:abc", plug: {Req.Test, Lux.Telegram.MockError})
  end

  test "raises without token" do
    assert_raise RuntimeError, ~r/token required/, fn ->
      Client.request("getMe", %{}, [])
    end
  end
end
