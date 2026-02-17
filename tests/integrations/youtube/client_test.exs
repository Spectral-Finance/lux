defmodule Lux.Integrations.Youtube.ClientTest do
  use ExUnit.Case
  alias Lux.Integrations.Youtube.Client

  setup do
    {:ok, api_key: Application.get_env(:lux, :youtube_api_key)}
  end

  test "search with valid query", %{api_key: api_key} do
    Application.put_env(:lux, :youtube_api_key, "test_api_key")
    response = Client.search("elixir programming")

    assert {:ok, %{"items" => items}} = response
    assert is_list(items)
  end

  test "search with invalid query", %{api_key: api_key} do
    Application.put_env(:lux, :youtube_api_key, "test_api_key")
    response = Client.search("nonexistent_query")

    assert {:error, _reason} = response
  end
end