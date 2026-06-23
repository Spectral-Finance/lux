defmodule Lux.Lenses.Twitter.AuthLensTest do
  use ExUnit.Case, async: true
  alias Lux.Lenses.Twitter.AuthLens

  test "returns a token structure on success" do
    response = %{
      "token_type" => "bearer",
      "expires_in" => 7200,
      "access_token" => "mock_token",
      "scope" => "tweet.read users.read offline.access",
      "refresh_token" => "mock_refresh_token"
    }

    assert {:ok, result} = AuthLens.after_focus(response)
    assert result.access_token == "mock_token"
    assert result.refresh_token == "mock_refresh_token"
    assert result.expires_in == 7200
  end

  test "returns error on failure" do
    response = %{"error" => "invalid_request", "error_description" => "Missing code"}
    assert {:error, "invalid_request: Missing code"} = AuthLens.after_focus(response)
    
    # Fallback error
    assert {:error, "Unknown error"} = AuthLens.after_focus(%{"error" => "Unknown error"})
  end
end
