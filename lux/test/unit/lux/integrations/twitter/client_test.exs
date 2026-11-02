defmodule Lux.Integrations.Twitter.ClientTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Client

  describe "request/3 with mock plugs" do
    test "handles successful 200 GET request and extracts rate limit headers" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.put_resp_header("x-rate-limit-limit", "300")
        |> Plug.Conn.put_resp_header("x-rate-limit-remaining", "299")
        |> Plug.Conn.put_resp_header("x-rate-limit-reset", "1700000000")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => %{"id" => "123", "text" => "mocked tweet"}}))
      end

      {:ok, response} =
        Client.request(:get, "/tweets/123", %{
          token: "mock_bearer_token",
          plug: plug
        })

      assert response["data"]["id"] == "123"
      assert response["data"]["text"] == "mocked tweet"
      assert response["_rate_limit"][:limit] == 300
      assert response["_rate_limit"][:remaining] == 299
      assert response["_rate_limit"][:reset] == 1_700_000_000
    end

    test "handles 401 Unauthorized" do
      plug = fn conn ->
        conn
        |> Plug.Conn.resp(401, Jason.encode!(%{"title" => "Unauthorized", "status" => 401}))
      end

      assert {:error, :unauthorized} =
               Client.request(:get, "/users/me", %{plug: plug})
    end

    test "handles 403 Forbidden" do
      plug = fn conn ->
        conn
        |> Plug.Conn.resp(403, %{"detail" => "Client not permitted"})
      end

      assert {:error, {:forbidden, _body}} =
               Client.request(:post, "/tweets", %{plug: plug, json: %{text: "hi"}})
    end

    test "handles 404 Not Found" do
      plug = fn conn ->
        conn
        |> Plug.Conn.resp(404, %{"title" => "Not Found"})
      end

      assert {:error, {:not_found, _}} =
               Client.request(:get, "/tweets/9999999999", %{plug: plug})
    end

    test "handles 429 Rate Limited with reset header" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-rate-limit-reset", "1750000000")
        |> Plug.Conn.resp(429, %{"title" => "Too Many Requests"})
      end

      assert {:error, {:rate_limited, 1_750_000_000, _}} =
               Client.request(:get, "/tweets/1", %{plug: plug})
    end
  end
end
