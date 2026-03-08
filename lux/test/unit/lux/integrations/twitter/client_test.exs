defmodule Lux.Integrations.Twitter.ClientTest do
  use UnitCase, async: true

  alias Lux.Integrations.Twitter.Client

  describe "request/3 with bearer token" do
    test "successful GET request" do
      plug = fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test_token"]
        conn |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"id" => "123"}}))
      end

      assert {:ok, %{data: %{"id" => "123"}}} =
               Client.request(:get, "/tweets/123", %{token: "test_token", plug: plug})
    end

    test "successful POST request with JSON body" do
      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert %{"text" => "Hello!"} = Jason.decode!(body)
        conn |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"id" => "456", "text" => "Hello!"}}))
      end

      assert {:ok, %{data: %{"id" => "456"}}} =
               Client.request(:post, "/tweets", %{
                 token: "test_token",
                 json: %{"text" => "Hello!"},
                 plug: plug
               })
    end

    test "handles 401 unauthorized" do
      plug = fn conn -> conn |> Plug.Conn.send_resp(401, "{}") end

      assert {:error, :unauthorized} =
               Client.request(:get, "/users/me", %{token: "bad_token", plug: plug})
    end

    test "handles 403 forbidden" do
      plug = fn conn -> conn |> Plug.Conn.send_resp(403, "{}") end

      assert {:error, :forbidden} =
               Client.request(:get, "/tweets/123", %{token: "test_token", plug: plug})
    end

    test "handles 429 rate limited" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-rate-limit-reset", "1700000000")
        |> Plug.Conn.send_resp(429, "{}")
      end

      assert {:error, {:rate_limited, 1_700_000_000}} =
               Client.request(:get, "/tweets/search/recent", %{token: "test_token", plug: plug})
    end

    test "handles API error with message" do
      plug = fn conn ->
        conn
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "errors" => [%{"message" => "Not Found"}]
        }))
      end

      assert {:error, {404, "Not Found"}} =
               Client.request(:get, "/tweets/999", %{token: "test_token", plug: plug})
    end

    test "extracts rate limit headers" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-rate-limit-remaining", "45")
        |> Plug.Conn.put_resp_header("x-rate-limit-limit", "50")
        |> Plug.Conn.put_resp_header("x-rate-limit-reset", "1700000000")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"id" => "1"}}))
      end

      assert {:ok, %{rate_limit: rate_limit}} =
               Client.request(:get, "/tweets/1", %{token: "test_token", plug: plug})

      assert rate_limit.remaining == 45
      assert rate_limit.limit == 50
      assert rate_limit.reset_at == 1_700_000_000
    end

    test "handles DELETE request" do
      plug = fn conn ->
        assert conn.method == "DELETE"
        conn |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"deleted" => true}}))
      end

      assert {:ok, %{data: %{"deleted" => true}}} =
               Client.request(:delete, "/tweets/123", %{token: "test_token", plug: plug})
    end
  end
end
