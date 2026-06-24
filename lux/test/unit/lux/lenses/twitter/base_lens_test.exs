defmodule Lux.Lenses.Twitter.BaseLensTest do
  use ExUnit.Case, async: false

  alias Lux.Lenses.Twitter.Base

  setup do
    Application.put_env(:lux, :api_keys, [
      twitter_bearer_token: "TEST_BEARER_TOKEN"
    ])
    :ok
  end

  describe "client/0" do
    test "returns a configured Req struct" do
      client = Base.client()
      assert client.options.base_url |> URI.to_string() == "https://api.twitter.com/2"
      assert {:bearer, "TEST_BEARER_TOKEN"} = client.options.auth
      assert {"accept", ["application/json"]} in client.options.headers
    end
  end

  describe "process_response/1" do
    test "processes a successful response" do
      response = {:ok, %Req.Response{status: 200, body: %{"data" => "success"}}}
      assert {:ok, %{"data" => "success"}} = Base.process_response(response)
    end

    test "processes an error response" do
      response = {:ok, %Req.Response{status: 400, body: %{"errors" => ["bad request"]}}}
      assert {:error, "Twitter API error (status 400): %{\"errors\" => [\"bad request\"]}"} = Base.process_response(response)
    end

    test "handles network error" do
      response = {:error, :nxdomain}
      assert {:error, "Request failed: :nxdomain"} = Base.process_response(response)
    end
  end
end
