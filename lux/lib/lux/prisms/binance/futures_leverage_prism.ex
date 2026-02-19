defmodule Lux.Prisms.Binance.FuturesLeveragePrism do
  @moduledoc """
  A prism that manages leverage and margin settings for Binance futures.

  Allows changing leverage, switching between cross and isolated margin modes,
  and adjusting isolated margin amounts for positions.

  ## Examples

      # Change leverage
      iex> Lux.Prisms.Binance.FuturesLeveragePrism.run(%{
      ...>   action: "set_leverage",
      ...>   symbol: "BTCUSDT",
      ...>   leverage: 10
      ...> })
      {:ok, %{status: "success", result: %{symbol: "BTCUSDT", leverage: 10}}}

      # Change margin type
      iex> Lux.Prisms.Binance.FuturesLeveragePrism.run(%{
      ...>   action: "set_margin_type",
      ...>   symbol: "ETHUSDT",
      ...>   margin_type: "ISOLATED"
      ...> })
      {:ok, %{status: "success", result: %{message: "success"}}}
  """

  use Lux.Prism,
    name: "Binance Futures Leverage",
    description: "Manages leverage and margin settings for Binance futures",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action to perform",
          enum: ["set_leverage", "set_margin_type"]
        },
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTCUSDT')"
        },
        leverage: %{
          type: :integer,
          description: "Leverage value (1-125, depending on symbol)",
          minimum: 1,
          maximum: 125
        },
        margin_type: %{
          type: :string,
          description: "Margin mode",
          enum: ["CROSSED", "ISOLATED"]
        }
      },
      required: ["action", "symbol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        result: %{type: :object}
      },
      required: ["status", "result"]
    }

  alias Lux.Integrations.Binance.Client

  require Logger

  def handler(params, ctx) do
    agent_name = get_in(ctx, [:agent, :name]) || "Unknown Agent"
    plug = Map.get(params, :plug)

    case params.action do
      "set_leverage" ->
        set_leverage(params, agent_name, plug)

      "set_margin_type" ->
        set_margin_type(params, agent_name, plug)

      action ->
        {:error, "Unknown action: #{action}"}
    end
  end

  defp set_leverage(params, agent_name, plug) do
    leverage = Map.fetch!(params, :leverage)
    Logger.info("Agent #{agent_name} setting leverage for #{params.symbol} to #{leverage}x")

    case Client.request(:post, "/fapi/v1/leverage",
           %{symbol: params.symbol, leverage: leverage},
           signed: true, endpoint: :futures, plug: plug) do
      {:ok, data} ->
        {:ok, %{
          status: "success",
          result: %{
            symbol: data["symbol"],
            leverage: data["leverage"],
            max_notional_value: data["maxNotionalValue"]
          }
        }}

      {:error, {_status, code, msg}} ->
        {:error, "Binance API error (#{code}): #{msg}"}

      {:error, reason} ->
        {:error, "Set leverage failed: #{inspect(reason)}"}
    end
  end

  defp set_margin_type(params, agent_name, plug) do
    margin_type = Map.fetch!(params, :margin_type)
    Logger.info("Agent #{agent_name} setting margin type for #{params.symbol} to #{margin_type}")

    case Client.request(:post, "/fapi/v1/marginType",
           %{symbol: params.symbol, marginType: margin_type},
           signed: true, endpoint: :futures, plug: plug) do
      {:ok, data} ->
        {:ok, %{
          status: "success",
          result: %{message: data["msg"] || "success"}
        }}

      {:error, {_status, -4046, _msg}} ->
        {:error, "Margin type already set to #{margin_type}"}

      {:error, {_status, code, msg}} ->
        {:error, "Binance API error (#{code}): #{msg}"}

      {:error, reason} ->
        {:error, "Set margin type failed: #{inspect(reason)}"}
    end
  end
end
