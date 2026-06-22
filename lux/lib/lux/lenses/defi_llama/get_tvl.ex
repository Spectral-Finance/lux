defmodule Lux.Lenses.DefiLlama.GetTvl do
  @moduledoc """
  A lens for fetching historical TVL data from DeFiLlama.
  """
  use Lux.Lens,
    name: "Get DeFiLlama Historical TVL",
    description: "Fetches historical Total Value Locked (TVL) data of DeFi on all chains",
    url: "\#{Lux.Integrations.DefiLlama.base_url()}/v2/historicalTvls",
    method: :get,
    headers: Lux.Integrations.DefiLlama.headers(),
    auth: Lux.Integrations.DefiLlama.auth(),
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  @impl true
  def after_focus(response) do
    case response do
      [first | _] = data when is_map(first) ->
        {:ok, data}

      %{"message" => msg} ->
        {:error, msg}

      error ->
        {:error, error}
    end
  end
end
