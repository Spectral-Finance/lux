defmodule Lux.Lenses.DeFiLlama.ProtocolTVLLens do
  @moduledoc """
  Lens for fetching TVL data for a specific protocol from the DeFiLlama API.

  ## Examples

      iex> Lux.Lenses.DeFiLlama.ProtocolTVLLens.focus(%{protocol: "aave"})
      {:ok, %{
        name: "Aave",
        slug: "aave",
        tvl: 1234567890.0,
        chain_tvls: %{"Ethereum" => 1000000000.0, "Polygon" => 234567890.0},
        tokens: [...],
        ...
      }}

  The response includes:
  - `name`: Protocol name
  - `slug`: Protocol slug identifier
  - `tvl`: Total value locked in USD
  - `chain_tvls`: TVL breakdown by chain
  - `tokens`: List of tokens and their values
  - `current_chain_tvls`: Current TVL by chain
  """

  alias Lux.Integrations.DeFiLlama

  use Lux.Lens,
    name: "DeFiLlama Protocol TVL",
    description: "Fetches detailed TVL data for a specific DeFi protocol from DeFiLlama",
    url: "#{DeFiLlama.base_url()}/protocol/:protocol",
    method: :get,
    headers: [{"accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        protocol: %{
          type: :string,
          description: "Protocol slug identifier (e.g. 'aave', 'uniswap', 'lido')"
        }
      },
      required: ["protocol"]
    }

  @impl true
  def before_focus(%{protocol: protocol} = params) do
    %{params | protocol: String.downcase(protocol)}
  end

  @impl true
  def after_focus(%{"name" => _name} = response) do
    {:ok,
     %{
       name: response["name"],
       slug: response["slug"],
       tvl: response["tvl"],
       chain_tvls: response["chainTvls"],
       current_chain_tvls: response["currentChainTvls"],
       tokens: response["tokens"],
       token_breakdowns: response["tokenBreakdowns"],
       raiding_tvl: response["raidingTvl"],
       change_1h: response["change_1h"],
       change_1d: response["change_1d"],
       change_7d: response["change_7d"],
       description: response["description"],
       category: response["category"],
       url: response["url"],
       gecko_id: response["gecko_id"],
       chains: response["chains"]
     }}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end
