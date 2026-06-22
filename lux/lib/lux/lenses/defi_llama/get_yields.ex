defmodule Lux.Lenses.DefiLlama.GetYields do
  @moduledoc """
  A lens for fetching pool yield analytics from DeFiLlama Yields.
  """
  use Lux.Lens,
    name: "Get DeFiLlama Pool Yields",
    description: "Fetches all yield pools along with their APY, TVL, and metrics",
    url: "\#{Lux.Integrations.DefiLlama.yields_url()}/pools",
    method: :get,
    headers: Lux.Integrations.DefiLlama.headers(),
    auth: Lux.Integrations.DefiLlama.auth(),
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  @impl true
  def after_focus(%{"data" => pools}) when is_list(pools) do
    {:ok, pools}
  end

  def after_focus(%{"status" => "error", "message" => msg}) do
    {:error, msg}
  end

  def after_focus(error) do
    {:error, error}
  end
end
