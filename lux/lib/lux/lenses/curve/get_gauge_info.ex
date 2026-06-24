defmodule Lux.Lenses.Curve.GetGaugeInfo do
  @moduledoc """
  Fetches gauge staking information for a Curve pool.

  ## Examples

      iex> GetGaugeInfo.focus(%{gauge_address: "0x..."})
      {:ok, %{data: %{...}}}
  """

  alias Lux.Integrations.Curve
  require Logger

  use Lux.Lens,
    name: "Curve Get Gauge Info",
    description: "Fetches gauge staking info for a Curve pool",
    url: "#{Curve.base_url()}/getGauge/ethereum/main",
    method: :get,
    headers: Curve.headers(),
    auth: Curve.auth(),
    schema: %{
      type: :object,
      properties: %{
        gauge_address: %{
          type: :string,
          description: "The Ethereum address of the gauge"
        }
      },
      required: ["gauge_address"]
    }

  def before_focus(%{gauge_address: address}) do
    %{url: "#{Lux.Integrations.Curve.base_url()}/getGauge/ethereum/main/#{address}"}
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
