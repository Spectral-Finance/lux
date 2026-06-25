defmodule Lux.Lenses.DeFiLlama.YieldData do
  @moduledoc """
  Lens for fetching yield/farming data from DeFiLlama.

  ## Examples

  ```elixir
  # Get all yield data
  Lux.Lenses.DeFiLlama.YieldData.focus(%{})

  # Filter by chain
  Lux.Lenses.DeFiLlama.YieldData.focus(%{chain: "Ethereum"})
  ```
  """

  use Lux.Lens,
    name: "DeFiLlama.YieldData",
    description: "Fetches yield farming data including APY, TVL, and pool information",
    url: "https://api.llama.fi/yield",
    method: :get,
    headers: [{"accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        chain: %{
          type: :string,
          description: "Optional chain filter (e.g., 'Ethereum', 'Arbitrum')"
        }
      },
      required: []
    }

  def after_focus(body) when is_list(body) do
    {:ok, %{
      pools: body,
      count: length(body),
      timestamp: DateTime.utc_now()
    }}
  end

  def after_focus(body) do
    {:ok, %{raw: body, timestamp: DateTime.utc_now()}}
  end
end
