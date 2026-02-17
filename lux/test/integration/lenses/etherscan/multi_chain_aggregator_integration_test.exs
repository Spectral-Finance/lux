defmodule Lux.Lenses.Etherscan.MultiChainAggregator do
  @moduledoc """
  Multi-chain aggregator for Etherscan API lenses.
  """

  alias Lux.Lenses.Etherscan.Base

  @doc """
  Aggregates data from multiple chains using the Etherscan API.
  """
  def aggregate_data(chains, endpoint, params) do
    Enum.map(chains, fn chain ->
      lens = %{
        params: params,
        headers: Base.default_headers()
      }

      lens = Base.add_api_key(lens)

      case HTTPoison.get(chain <> endpoint, lens.headers, query: lens.params) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          response = Jason.decode!(body)
          {:ok, Base.process_response(response)}

        {:error, %HTTPoison.Error{reason: reason}} ->
          {:error, "Failed to fetch data from #{chain}: #{reason}"}
      end
    end)
  end
end

defmodule Lux.Lenses.Etherscan.MultiChainAggregatorIntegrationTest do
  import ExUnit.Case, async: true
  use HTTPoison.Base
  alias Lux.Lenses.Etherscan.MultiChainAggregator

  test "aggregates data from multiple chains" do
    chains = ["https://api.etherscan.io/", "https://api.bscscan.com/"]
    endpoint = "/api"
    params = %{"module" => "account", "action" => "balance", "address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"}

    result = MultiChainAggregator.aggregate_data(chains, endpoint, params)

    assert Enum.all?(result, fn {:ok, _} -> true end)
  end
end