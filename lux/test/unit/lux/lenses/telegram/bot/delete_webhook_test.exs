defmodule Lux.Lenses.Telegram.Bot.DeleteWebhookTest do
  @moduledoc """
  Test suite for the DeleteWebhook lens.
  These tests verify the lens's ability to:
  - Remove webhook integrations
  - Handle optional drop_pending_updates parameter
  - Handle Telegram API errors appropriately
  - Handle rate limiting (429 responses)
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Bot.DeleteWebhook

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully deletes a webhook" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/deleteWebhook")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true,
          "description" => "Webhook was deleted"
        }))
      end)

      assert {:ok, %{deleted: true, description: "Webhook was deleted"}} =
        DeleteWebhook.focus(%{}, %{})
    end

    test "successfully deletes webhook and drops pending updates" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["drop_pending_updates"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true,
          "description" => "Webhook was deleted"
        }))
      end)

      assert {:ok, %{deleted: true}} =
        DeleteWebhook.focus(%{drop_pending_updates: true}, %{})
    end

    test "handles Telegram API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 401,
          "description" => "Unauthorized"
        }))
      end)

      assert {:error, %{reason: :api_error, error_code: 401}} =
        DeleteWebhook.focus(%{}, %{})
    end

    test "handles rate limiting (429)" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests: retry after 5",
          "parameters" => %{"retry_after" => 5}
        }))
      end)

      assert {:error, %{reason: :rate_limited, retry_after: 5}} =
        DeleteWebhook.focus(%{}, %{})
    end
  end

  describe "schema validation" do
    test "has no required fields" do
      lens = DeleteWebhook.view()
      assert lens.schema.required == []
    end

    test "validates schema properties" do
      lens = DeleteWebhook.view()
      assert Map.has_key?(lens.schema.properties, :drop_pending_updates)
    end
  end
end
