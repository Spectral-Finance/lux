defmodule Lux.Lenses.PancakeSwap.Farms.GetFarms do
  @moduledoc """
  Lists all PancakeSwap yield farms.

  ## Examples

      iex> GetFarms.focus(%{})
      {:ok, %{data: %{...}}}
  """

  alias Lux.Integrations.PancakeSwap
  require Logger

  use Lux.Lens,
    name: "PancakeSwap Get Farms",
    description: "Lists all PancakeSwap yield farms",
    url: "#{PancakeSwap.base_url()}/farms",
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
