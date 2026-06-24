defmodule Lux.Lenses.Curve.GetPoolInfo do
  @moduledoc """
  Fetches detailed information about a specific Curve pool.

  ## Examples

      iex> GetPoolInfo.focus(%{pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"})
      {:ok, %{data: %{...}}}
  """

  alias Lux.Integrations.Curve
  require Logger

  use Lux.Lens,
    name: "Curve Get Pool Info",
    description: "Fetches detailed info about a specific Curve pool",
    url: "#{Curve.base_url()}/getPool/ethereum/main",
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
    %{url: "#{Lux.Integrations.Curve.base_url()}/getPool/ethereum/main/#{address}"}
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
