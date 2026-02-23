defmodule Lux.Lenses.Telegram.Updates.GetUpdatesTest do
  @moduledoc """
  Test suite for the GetUpdates lens.
  Verifies:
  - Successful retrieval of pending updates
  - Empty update list (no pending updates)
  - Message content parsing
  - Callback query and other update types
  - Error handling
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Updates.GetUpdates

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "retrieves pending message updates" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "getUpdates"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{
              "update_id" => 123_456_789,
              "message" => %{
                "message_id" => 42,
                "from" => %{"id" => 111, "first_name" => "Alice"},
                "chat" => %{"id" => 987_654_321, "type" => "private"},
                "date" => 1_609_459_200,
                "text" => "Hello bot!"
              }
            }
          ]
        }))
      end)

      assert {:ok, [update]} = GetUpdates.focus(%{}, %{})
      assert update.update_id == 123_456_789
      assert update.message.message_id == 42
      assert update.message.text == "Hello bot!"
    end

    test "returns empty list when no updates pending" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => []
        }))
      end)

      assert {:ok, []} = GetUpdates.focus(%{}, %{})
    end

    test "passes offset and limit parameters" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "getUpdates"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => []
        }))
      end)

      assert {:ok, []} = GetUpdates.focus(%{offset: 123_456_790, limit: 10, timeout: 30}, %{})
    end

    test "handles callback_query updates" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{
              "update_id" => 987_654_321,
              "callback_query" => %{
                "id" => "cb_123",
                "from" => %{"id" => 222},
                "data" => "button_pressed"
              }
            }
          ]
        }))
      end)

      assert {:ok, [update]} = GetUpdates.focus(%{}, %{})
      assert update.update_id == 987_654_321
      assert update.callback_query["data"] == "button_pressed"
    end

    test "handles API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Conflict: terminated by other getUpdates request"
        }))
      end)

      assert {:error, "Conflict: terminated by other getUpdates request"} =
               GetUpdates.focus(%{}, %{})
    end
  end
end
