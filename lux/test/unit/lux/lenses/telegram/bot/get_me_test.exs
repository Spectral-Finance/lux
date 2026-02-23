defmodule Lux.Lenses.Telegram.Bot.GetMeTest do
  @moduledoc """
  Test suite for the GetMe lens.
  Verifies:
  - Successful bot info retrieval
  - Handling of authentication errors
  - Handling of API errors
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Bot.GetMe

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves bot information" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "getMe"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "id" => 123_456_789,
            "is_bot" => true,
            "first_name" => "MyBot",
            "username" => "my_test_bot",
            "can_join_groups" => true,
            "can_read_all_group_messages" => false,
            "supports_inline_queries" => false
          }
        }))
      end)

      assert {:ok, result} = GetMe.focus(%{}, %{})
      assert result.id == 123_456_789
      assert result.is_bot == true
      assert result.first_name == "MyBot"
      assert result.username == "my_test_bot"
      assert result.can_join_groups == true
      assert result.can_read_all_group_messages == false
      assert result.supports_inline_queries == false
    end

    test "handles bot with optional fields present" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "id" => 111_111_111,
            "is_bot" => true,
            "first_name" => "TestBot",
            "last_name" => "Assistant",
            "username" => "test_assistant_bot",
            "can_join_groups" => false,
            "can_read_all_group_messages" => true,
            "supports_inline_queries" => true
          }
        }))
      end)

      assert {:ok, result} = GetMe.focus(%{}, %{})
      assert result.last_name == "Assistant"
      assert result.supports_inline_queries == true
    end

    test "handles API error with description" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Unauthorized"
        }))
      end)

      assert {:error, "Unauthorized"} = GetMe.focus(%{}, %{})
    end
  end

  describe "view/0" do
    test "returns lens metadata" do
      lens = GetMe.view()
      assert lens.name == "Get Telegram Bot Info"
      assert lens.url =~ "getMe"
      assert lens.method == :get
    end
  end
end
