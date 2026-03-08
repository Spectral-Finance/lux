defmodule Lux.Lenses.Telegram.GetMeTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Telegram.GetMe

  setup do
    Req.Test.stub(Lux.Telegram.GetMeMock, fn conn ->
      Req.Test.json(conn, %{
        "ok" => true,
        "result" => %{
          "id" => 123456,
          "is_bot" => true,
          "first_name" => "TestBot",
          "username" => "test_bot"
        }
      })
    end)

    :ok
  end

  test "returns bot info" do
    assert {:ok, result} = GetMe.focus(%{token: "123:abc", plug: {Req.Test, Lux.Telegram.GetMeMock}})
    assert result["id"] == 123456
    assert result["username"] == "test_bot"
  end
end
