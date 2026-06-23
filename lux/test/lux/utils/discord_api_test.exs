defmodule Lux.Utils.DiscordApiTest do
  use ExUnit.Case, async: true

  alias Lux.Utils.DiscordApi

  # Assuming DiscordApi uses Req under the hood, we can mock it using bypass or just test the response parsing logic
  describe "handle_response/1" do
    test "returns :ok for 2xx status" do
      response = %Req.Response{status: 200, body: %{"id" => "123"}}
      assert {:ok, %{"id" => "123"}} = DiscordApi.handle_response({:ok, response})
    end

    test "returns rate limit error for 429 status" do
      # X-RateLimit-Reset is usually a unix epoch timestamp in seconds or similar,
      # but retry_after might be a direct value. Let's say we expect retry_after.
      response = %Req.Response{
        status: 429,
        headers: [{"x-ratelimit-reset", "1700000000"}],
        body: %{"message" => "You are being rate limited.", "retry_after" => 0.5}
      }
      
      # Let's say DiscordApi returns {:error, :rate_limit, retry_after_in_seconds}
      assert {:error, :rate_limit, retry_after} = DiscordApi.handle_response({:ok, response})
      assert retry_after == 0.5
    end

    test "returns error for other statuses" do
      response = %Req.Response{status: 400, body: %{"message" => "Bad Request"}}
      assert {:error, %{"message" => "Bad Request"}} = DiscordApi.handle_response({:ok, response})
    end
  end
end
