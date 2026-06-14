defmodule Lux.Prisms.YouTube.YouTubeAuthPrismTest do
  use UnitCase, async: true
  alias Lux.Prisms.YouTube.YouTubeAuthPrism

  @moduletag :unit

  setup do
    System.put_env("YOUTUBE_CLIENT_ID", "test_client_id")
    System.put_env("YOUTUBE_CLIENT_SECRET", "test_client_secret")
    System.put_env("YOUTUBE_REDIRECT_URI", "http://localhost:4000/callback")
    :ok
  end

  test "get_auth_url returns valid OAuth URL" do
    {:ok, result} = YouTubeAuthPrism.handler(%{action: "get_auth_url"}, %{})
    assert result.status == "success"
    assert String.contains?(result.auth_url, "accounts.google.com")
    assert String.contains?(result.auth_url, "test_client_id")
    assert String.contains?(result.auth_url, "youtube")
  end

  test "exchange_code handles API error" do
    Req.Test.stub(YouTubeAuthPrism, fn conn ->
      Req.Test.json(conn, %{"error" => "invalid_grant"}, status: 400)
    end)
    result = YouTubeAuthPrism.handler(%{action: "exchange_code", code: "bad_code"}, %{})
    assert {:error, _} = result
  end

  test "refresh_token handles API error" do
    Req.Test.stub(YouTubeAuthPrism, fn conn ->
      Req.Test.json(conn, %{"error" => "invalid_grant"}, status: 400)
    end)
    result = YouTubeAuthPrism.handler(%{action: "refresh_token", refresh_token: "bad_token"}, %{})
    assert {:error, _} = result
  end

  test "unknown action returns error" do
    result = YouTubeAuthPrism.handler(%{action: "unknown"}, %{})
    assert {:error, "Unknown action: unknown"} = result
  end
end
