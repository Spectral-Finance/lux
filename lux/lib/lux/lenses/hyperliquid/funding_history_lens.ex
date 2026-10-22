defmodule Lux.Lenses.Hyperliquid.FundingHistoryLens do
  @moduledoc """
  A lens for querying historical funding rates for perpetual assets on Hyperliquid.

  ## Examples

      iex> FundingHistoryLens.focus(%{coin: "BTC", start_time: 1700000000000})
      {:ok, %{
        coin: "BTC",
        funding_history: [...]
      }}
  """

  use Lux.Lens,
    name: "Hyperliquid Funding History Lens",
    description: "Queries historical funding rate timestamps and payments from Hyperliquid",
    url: "https://api.hyperliquid.xyz/info",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Coin symbol (e.g. BTC, ETH)"
        },
        start_time: %{
          type: :integer,
          description: "Start timestamp in milliseconds"
        },
        end_time: %{
          type: :integer,
          description: "Optional end timestamp in milliseconds"
        }
      },
      required: ["coin", "start_time"]
    }

  def before_focus(params) do
    coin = Map.get(params, :coin) || Map.get(params, "coin")
    start_time = Map.get(params, :start_time) || Map.get(params, "start_time")
    end_time = Map.get(params, :end_time) || Map.get(params, "end_time")

    body = %{
      "type" => "fundingHistory",
      "coin" => coin,
      "startTime" => start_time
    }

    if end_time do
      Map.put(body, "endTime", end_time)
    else
      body
    end
  end

  @doc """
  Transforms funding history items into structured maps.
  """
  @impl true
  def after_focus(history) when is_list(history) do
    transformed =
      Enum.map(history, fn item ->
        %{
          coin: item["coin"],
          funding_rate: parse_float(item["fundingRate"]),
          premium: parse_float(item["premium"]),
          time: item["time"]
        }
      end)

    {:ok, %{funding_history: transformed}}
  end

  @impl true
  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  @impl true
  def after_focus(other) do
    {:error, "Unexpected funding history response format: #{inspect(other)}"}
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp parse_float(_), do: 0.0
end
