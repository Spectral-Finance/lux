defmodule Lux.Integrations.Discord.ClientTest do
  @moduledoc """
  Test suite for Discord Client with retry logic.
  """

  use UnitAPICase, async: true
  alias Lux.Integrations.Discord.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "request_with_retry/3" do
    test "retries on 429 rate limit and succeeds" do
      call_count = 0

      Req.Test.expect(DiscordClientMock, fn conn ->
        call_count = call_count + 1
        
        if call_count == 1 do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(429, Jason.encode!(%{
            "message" => "Rate limited",
            "retry_after" => 0.1
          }))
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{
            "id" => "123",
            "username" => "test"
          }))
        end
      end)

      assert {:ok, %{"id" => "123", "username" => "test"}} = Client.request_with_retry(
        :get,
        "/users/@me",
        %{token: "test-token", max_retries: 3, plug: {Req.Test, DiscordClientMock}}
      )

      assert call_count == 2
    end

    test "retries on 500 server error and succeeds" do
      call_count = 0

      Req.Test.expect(DiscordClientMock, fn conn ->
        call_count = call_count + 1
        
        if call_count == 1 do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(500, Jason.encode!(%{"message" => "Internal Server Error"}))
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{
            "id" => "123",
            "username" => "test"
          }))
        end
      end)

      assert {:ok, %{"id" => "123", "username" => "test"}} = Client.request_with_retry(
        :get,
        "/users/@me",
        %{token: "test-token", max_retries: 3, plug: {Req.Test, DiscordClientMock}}
      )

      assert call_count == 2
    end

    test "does not retry on 404" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"message" => "Not Found"}))
      end)

      assert {:error, {404, "Not Found"}} = Client.request_with_retry(
        :get,
        "/channels/999999999999999999",
        %{token: "test-token", max_retries: 3, plug: {Req.Test, DiscordClientMock}}
      )
    end

    test "fails after max retries exhausted" do
      call_count = 0

      Req.Test.expect(DiscordClientMock, fn conn ->
        call_count = call_count + 1
        
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "message" => "Rate limited",
          "retry_after" => 0.1
        }))
      end)

      assert {:error, {429, "Rate limited"}} = Client.request_with_retry(
        :get,
        "/users/@me",
        %{token: "test-token", max_retries: 2, plug: {Req.Test, DiscordClientMock}}
      )

      assert call_count == 3  # Initial + 2 retries
    end
  end
end