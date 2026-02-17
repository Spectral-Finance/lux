defmodule Lux.Integrations.Youtube.Agents.CommunityManagerTest do
  use ExUnit.Case
  alias Lux.Integrations.Youtube.Client

  setup do
    {:ok, api_key: Application.get_env(:lux, :youtube_api_key)}
  end

  test "searches for videos", %{api_key: api_key} do
    query = "elixir programming"
    params = [
      q: query,
      part: "snippet",
      key: api_key
    ]

    url = "#{Client.@base_url}/search"

    response = HTTPoison.get(url, [], params: params)

    assert {:ok, %HTTPoison.Response{status_code: 200}} = response
    assert %{"items" => items} = Poison.decode!(response.body)
    assert is_list(items)
  end

  test "handles search errors", %{api_key: api_key} do
    query = "nonexistentquery"
    params = [
      q: query,
      part: "snippet",
      key: api_key
    ]

    url = "#{Client.@base_url}/search"

    response = HTTPoison.get(url, [], params: params)

    assert {:error, %HTTPoison.Error{reason: reason}} = response
    assert String.contains?(reason, "Not a valid query")
  end
end