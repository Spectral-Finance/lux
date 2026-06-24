defmodule Lux.Lenses.PancakeSwap.Pools.GetPools do
  @moduledoc """
  Lists all PancakeSwap liquidity pools.

  ## Examples

      iex> GetPools.focus(%{})
      {:ok, %{data: %{...}}}
  """

  alias Lux.Integrations.PancakeSwap
  require Logger

  use Lux.Lens,
    name: "PancakeSwap Get Pools",
    description: "Lists all PancakeSwap liquidity pools",
    url: "#{PancakeSwap.base_url()}/pools",
    method: :get,
    headers: PancakeSwap.headers(),
    auth: PancakeSwap.auth(),
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  def after_focus(%{"data" => data}) do
    {:ok, data}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
