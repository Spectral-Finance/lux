defmodule Lux.Lenses.PancakeSwap.Pools.GetPoolInfo do
  @moduledoc """
  Fetches detailed info about a specific PancakeSwap pool.

  ## Examples

      iex> GetPoolInfo.focus(%{address: "0x..."})
      {:ok, %{data: %{...}}}
  """

  alias Lux.Integrations.PancakeSwap
  require Logger

  use Lux.Lens,
    name: "PancakeSwap Get Pool Info",
    description: "Fetches info about a PancakeSwap pool",
    url: "#{PancakeSwap.base_url()}/pools",
    method: :get,
    headers: PancakeSwap.headers(),
    auth: PancakeSwap.auth(),
    schema: %{
      type: :object,
      properties: %{
        address: %{type: :string, description: "The pool contract address"}
      },
      required: ["address"]
    }

  def before_focus(%{address: address}) do
    %{url: "#{Lux.Integrations.PancakeSwap.base_url()}/pools/#{address}"}
  end

  def after_focus(%{"data" => data}) do
    {:ok, data}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
