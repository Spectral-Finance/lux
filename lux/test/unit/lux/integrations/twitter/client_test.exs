defmodule Lux.Integrations.Twitter.ClientTest do
  @moduledoc """
  Test suite for the Twitter API Client.
  """

  use UnitAPICase, async: true
  alias Lux.Integrations.Twitter.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "request/3" do
    test "makes GET request with Bearer token" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/123"
        assert ["Bearer test-twitter-token"] = Plug.Conn.get_req_header(conn, "authorization")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"id" => "123", "text" => "test"}
        }))
      end)

      assert {:ok, %{"data" => %{"id" => "123"}}} = Client.request(:get, "/tweets/123")
    end

    test "makes POST request with JSON body" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"text" => "Hello!"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{"id" => "456", "text" => "Hello!"}
        }))
      end)

      assert {:ok, %{"data" => %{"id" => "456"}}} = Client.request(:post, "/tweets", %{
        json: %{"text" => "Hello!"}
      })
    end

    test "handles 401 unauthorized" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      assert {:error, :invalid_token} = Client.request(:get, "/tweets/123")
    end

    test "handles rate limiting" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-rate-limit-reset", to_string(System.system_time(:second) + 60))
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"title" => "Too Many Requests"}))
      end)

      assert {:error, {:rate_limited, _}} = Client.request(:get, "/tweets/123", %{max_retries: 0})
    end
  end
end
