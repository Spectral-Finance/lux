defmodule Lux.Lenses.Curve.GetYields do
  @moduledoc """
  Fetches yield/APY data for Curve pools to identify optimal yield strategies.

  ## Examples

      iex> GetYields.focus(%{})
      {:ok, %{data: [%{pool: "3pool", apy: 12.5}]}}
  """

  alias Lux.Integrations.Curve
  require Logger

  use Lux.Lens,
    name: "Curve Get Yields",
    description: "Fetches yield data for Curve pools",
    url: "#{Curve.base_url()}/getYield/ethereum/main",
    method: :get,
    headers: Curve.headers(),
    auth: Curve.auth(),
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

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
