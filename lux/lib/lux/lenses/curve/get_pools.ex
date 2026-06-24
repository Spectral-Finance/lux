defmodule Lux.Lenses.Curve.GetPools do
  @moduledoc """
  Lists all Curve Finance pools with their metadata and TVL.

  ## Examples

      iex> GetPools.focus(%{})
      {:ok, %{data: [%{id: "0x...", name: "3pool", tvl: 100_000_000.0}]}}
  """

  alias Lux.Integrations.Curve
  require Logger

  use Lux.Lens,
    name: "Curve Get Pools",
    description: "Lists all Curve Finance pools with metadata",
    url: "#{Curve.base_url()}/getPools/ethereum/main",
    method: :get,
    headers: Curve.headers(),
    auth: Curve.auth(),
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  def after_focus(%{"data" => %{"poolData" => pools}}) do
    Logger.info("Successfully fetched #{length(pools)} Curve pools")
    {:ok, %{pools: pools}}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
