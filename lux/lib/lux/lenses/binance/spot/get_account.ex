defmodule Lux.Lenses.Binance.Spot.GetAccount do
  @moduledoc """
  Fetches Binance account information including balances.

  ## Examples

      iex> GetAccount.focus(%{})
      {:ok, %{balances: [...]}}
  """

  alias Lux.Integrations.Binance
  require Logger

  use Lux.Lens,
    name: "Binance Get Account",
    description: "Fetches Binance account balances and info",
    url: "#{Binance.base_url()}/api/v3/account",
    method: :get,
    headers: Binance.headers(),
    auth: Binance.auth(),
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  def after_focus(body) when is_map(body) do
    {:ok, body}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
