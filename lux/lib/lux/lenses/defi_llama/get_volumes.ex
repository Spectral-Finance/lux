defmodule Lux.Lenses.DefiLlama.GetVolumes do
  @moduledoc """
  A lens for fetching DEX volume analytics from DeFiLlama.
  """
  use Lux.Lens,
    name: "Get DeFiLlama Volumes",
    description: "Fetches DEX overview including volume and market share",
    url: "\#{Lux.Integrations.DefiLlama.base_url()}/overview/dexs?excludeTotalDataChart=true&excludeTotalDataChartBreakdown=true",
    method: :get,
    headers: Lux.Integrations.DefiLlama.headers(),
    auth: Lux.Integrations.DefiLlama.auth(),
    schema: %{
      type: :object,
      properties: %{
        dataType: %{
          type: :string,
          description: "Data type to fetch (e.g., dailyVolume)"
        }
      },
      required: []
    }

  @impl true
  def after_focus(%{"protocols" => protocols} = response) do
    {:ok, Map.put(response, "protocols", protocols)}
  end

  def after_focus(%{"message" => msg}) do
    {:error, msg}
  end

  def after_focus(error) do
    {:error, error}
  end
end
