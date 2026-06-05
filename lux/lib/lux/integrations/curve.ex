defmodule Lux.Integrations.Curve do
  @moduledoc "Curve Finance integration for stablecoin DEX operations."
  @api_url "https://api.curve.fi/api"
  def pools, do: get("/getPools/ethereum/main")
  def factory_pools, do: get("/getFactoryPools/ethereum")
  def volumes, do: get("/getVolumes/ethereum")
  def daily_volumes, do: get("/getDailyVolumes/ethereum")
  def hourly_volumes, do: get("/getHourlyVolumes/ethereum")
  defp get(path) do
    case Req.get(@api_url <> path) do
      {:ok, %{status: 200, body: %{"data" => d}}} -> {:ok, d}
      {:ok, %{status: 200, body: b}} -> {:ok, b}
      {:ok, %{status: s, body: b}} -> {:error, {s, b}}
      {:error, e} -> {:error, inspect(e)}
    end
  end
end