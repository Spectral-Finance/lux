defmodule Lux.Lenses.DeFiLlama.Volume do
  @moduledoc """
  Lens for fetching volume data for a specific DeFi protocol.

  ## Examples

  ```elixir
  # Get volume data for Uniswap
  Lux.Lenses.DeFiLlama.Volume.focus(%{protocol: "uniswap"})
  ```
  """

  use Lux.Lens,
    name: "DeFiLlama.Volume",
    description: "Fetches trading volume history for a specific DeFi protocol",
    url: "https://api.llama.fi/volume/:protocol",
    method: :get,
    headers: [{"accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        protocol: %{
          type: :string,
          description: "Protocol slug (e.g., 'uniswap', 'aave')"
        }
      },
      required: ["protocol"]
    }

  def before_focus(params) do
    protocol = Map.get(params, :protocol, "")
    %{params | protocol: URI.encode(protocol)}
  end

  def after_focus(body) when is_map(body) do
    {:ok, %{
      volume: body,
      timestamp: DateTime.utc_now()
    }}
  end

  def after_focus(body) do
    {:ok, %{raw: body, timestamp: DateTime.utc_now()}}
  end
end
