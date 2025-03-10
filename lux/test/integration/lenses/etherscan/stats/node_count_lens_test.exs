defmodule Lux.Integration.Etherscan.NodeCountLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.NodeCount
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthNodeCountLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Node Count API",
      description: "Fetches the total number of nodes currently syncing on the Ethereum network",
      url: "https://api.etherscan.io/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "stats")
      |> Map.put(:action, "nodecount")
    end
  end

  test "can fetch node count" do
    assert {:ok, %{result: node_count, node_count: node_count}} =
             RateLimitedAPI.call_standard(NodeCount, :focus, [%{
               chainid: 1
             }])

    # Verify the structure of the response
    assert is_map(node_count)
    assert Map.has_key?(node_count, :total)
    
    # Convert total to integer if it's a string
    total = case node_count.total do
      total when is_binary(total) -> 
        case Integer.parse(total) do
          {int, _} -> int
          :error -> 0
        end
      total when is_integer(total) -> total
      _ -> 0
    end
    
    # Total node count should be a positive number
    assert total > 0
  end

  test "fails when no auth is provided" do
    # The NoAuthNodeCountLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthNodeCountLens, :focus, [%{
      chainid: 1
    }])

    case result do
      {:ok, %{"status" => "0", "message" => "NOTOK", "result" => error_message}} ->
        assert String.contains?(error_message, "Missing/Invalid API Key")

      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil
    end
  end
end
