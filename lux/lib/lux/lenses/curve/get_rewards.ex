defmodule Lux.Lenses.Curve.GetRewards do
  @moduledoc """
  Fetches CRV reward information for a Curve pool or gauge.

  ## Examples

      iex> GetRewards.focus(%{pool_address: "0x..."})
      {:ok, %{data: %{...}}}
  """

  alias Lux.Integrations.Curve
  require Logger

  use Lux.Lens,
    name: "Curve Get Rewards",
    description: "Fetches CRV reward data for a Curve pool",
    url: "#{Curve.base_url()}/getRewards/ethereum/main",
    method: :get,
    headers: Curve.headers(),
    auth: Curve.auth(),
    schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "The Ethereum address of the pool"
        }
      },
      required: ["pool_address"]
    }

  def before_focus(%{pool_address: address}) do
    %{url: "#{Lux.Integrations.Curve.base_url()}/getRewards/ethereum/main/#{address}"}
  end

  def after_focus(%{"data" => data}) do
    {:ok, data}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
