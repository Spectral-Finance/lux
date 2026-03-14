defmodule Lux.Lenses.Telegram.Bot.GetMeTest do
  @moduledoc """
  Test suite for the GetMe lens.
  These tests verify the lens's ability to:
  - Retrieve bot information from Telegram
  - Handle Telegram API errors appropriately
  - Handle rate limiting (429 responses)
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Bot.GetMe

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully gets bot info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/getMe")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "id" => 123_456_789,
            "is_bot" => true,
            "first_name" => "TestBot",
            "username" => "test_bot",
            "can_join_groups" => true,
            "can_read_all_group_messages" => false,
            "supports_inline_queries" => false
          }
        }))
      end)

      assert {:ok, %{
        id: 123_456_789,
        is_bot: true,
        first_name: "TestBot",
        username: "test_bot",
        can_join_groups: true,
        can_read_all_group_messages: false,
        supports_inline_queries: false
      }} = GetMe.focus(%{}, %{})
    end

    test "handles unauthorized error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 401,
          "description" => "Unauthorized"
        }))
      end)

      assert {:error, %{reason: :api_error, error_code: 401, description: "Unauthorized"}} =
        GetMe.focus(%{}, %{})
    end

    test "handles rate limiting (429)" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests: retry after 60",
          "parameters" => %{"retry_after" => 60}
        }))
      end)

      assert {:error, %{reason: :rate_limited, retry_after: 60}} =
        GetMe.focus(%{}, %{})
    end
  end

  describe "schema validation" do
    test "has no required fields" do
      lens = GetMe.view()
      assert lens.schema.required == []
    end

    test "has empty properties" do
      lens = GetMe.view()
      assert lens.schema.properties == %{}
    end
  end
end
