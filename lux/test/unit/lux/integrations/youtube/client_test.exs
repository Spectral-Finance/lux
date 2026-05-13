defmodule Lux.Integrations.YouTube.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "request/3" do
    test "sends authenticated Data API requests with query params" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/videos"
        assert conn.params["part"] == "snippet,status"
        assert conn.params["id"] == "video-123"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer access-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "kind" => "youtube#videoListResponse",
          "items" => [%{"id" => "video-123"}]
        }))
      end)

      assert {:ok, %{"items" => [%{"id" => "video-123"}]}} =
               Client.request(:get, "/videos", %{
                 access_token: "access-token",
                 params: %{part: "snippet,status", id: "video-123"},
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "adds API key for read-only requests" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        assert conn.request_path == "/youtube/v3/channels"
        assert conn.params["key"] == "api-key"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:ok, %{"items" => []}} =
               Client.request(:get, "/channels", %{
                 api_key: "api-key",
                 params: %{part: "snippet", mine: true},
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "normalizes YouTube API errors" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{
            "code" => 403,
            "message" => "The request cannot be completed because you have exceeded your quota.",
            "errors" => [%{"reason" => "quotaExceeded"}]
          }
        }))
      end)

      assert {:error, {403, message, [%{"reason" => "quotaExceeded"}]}} =
               Client.request(:get, "/videos", %{
                 access_token: "access-token",
                 plug: {Req.Test, __MODULE__}
               })

      assert message =~ "exceeded your quota"
    end

    test "retries retryable YouTube rate-limit responses" do
      test_pid = self()
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      Req.Test.stub(__MODULE__, fn conn ->
        attempt = Agent.get_and_update(counter, fn value -> {value, value + 1} end)

        if attempt == 0 do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.put_resp_header("retry-after", "2")
          |> Plug.Conn.send_resp(403, Jason.encode!(%{
            "error" => %{
              "code" => 403,
              "message" => "Rate Limit Exceeded",
              "errors" => [%{"reason" => "rateLimitExceeded"}]
            }
          }))
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => [%{"id" => "ok"}]}))
        end
      end)

      assert {:ok, %{"items" => [%{"id" => "ok"}]}} =
               Client.request(:get, "/videos", %{
                 access_token: "access-token",
                 max_retries: 1,
                 sleep: fn delay_ms -> send(test_pid, {:slept, delay_ms}) end,
                 plug: {Req.Test, __MODULE__}
               })

      assert_received {:slept, 2000}
      assert Agent.get(counter, & &1) == 2
    end
  end
end
