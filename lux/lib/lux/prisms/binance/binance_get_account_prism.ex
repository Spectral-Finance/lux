defmodule Lux.Prisms.Binance.GetAccountPrism do
  @moduledoc """
  A prism for retrieving account information from Binance.

  Returns balances, trading permissions, and account status.

  ## Examples

      iex> Lux.Prisms.Binance.GetAccountPrism.handler(%{}, %{name: "Agent"})
      {:ok, %{
        can_trade: true,
        can_withdraw: true,
        can_deposit: true,
        balances: [%{asset: "BTC", free: "0.001", locked: "0.0"}]
      }}
  """

  use Lux.Prism,
    name: "Binance Get Account",
    description: "Retrieves account information and balances from Binance",
    input_schema: %{
      type: :object,
      properties: %{
        futures: %{
          type: :boolean,
          description: "If true, get Futures account info",
          default: false
        },
        hide_zero_balances: %{
          type: :boolean,
          description: "If true, filter out assets with zero balance",
          default: true
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        can_trade: %{type: :boolean, description: "Whether account can trade"},
        can_withdraw: %{type: :boolean, description: "Whether account can withdraw"},
        can_deposit: %{type: :boolean, description: "Whether account can deposit"},
        balances: %{
          type: :array,
          description: "List of asset balances",
          items: %{
            type: :object,
            properties: %{
              asset: %{type: :string},
              free: %{type: :string},
              locked: %{type: :string}
            }
          }
        }
      },
      required: ["can_trade", "balances"]
    }

  alias Lux.Integrations.Binance
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    futures = Map.get(params, :futures, false)
    hide_zero = Map.get(params, :hide_zero_balances, true)

    Logger.info("Agent #{agent_name} fetching account info (futures: #{futures})")

    path = if futures, do: "/fapi/v2/account", else: "/api/v3/account"

    case Binance.get(path, %{}, futures: futures, signed: true) do
      {:ok, data} ->
        balances = parse_balances(data, futures, hide_zero)
        result = %{
          can_trade: data["canTrade"] || data["canTrade"],
          can_withdraw: data["canWithdraw"],
          can_deposit: data["canDeposit"],
          balances: balances
        }
        Logger.info("Account info fetched: #{length(balances)} non-zero balances")
        {:ok, result}

      {:error, {status, %{"msg" => msg}}} ->
        Logger.error("Binance account error: #{status} - #{msg}")
        {:error, {status, msg}}

      {:error, reason} ->
        Logger.error("Binance account request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_balances(%{"balances" => balances}, _futures, hide_zero) do
    balances
    |> Enum.filter(fn b ->
      not hide_zero or
        (parse_float(b["free"]) > 0 or parse_float(b["locked"]) > 0)
    end)
    |> Enum.map(fn b ->
      %{asset: b["asset"], free: b["free"], locked: b["locked"]}
    end)
  end

  defp parse_balances(%{"assets" => assets}, true, hide_zero) do
    assets
    |> Enum.filter(fn a ->
      not hide_zero or
        parse_float(a["walletBalance"]) > 0
    end)
    |> Enum.map(fn a ->
      %{
        asset: a["asset"],
        free: a["availableBalance"],
        locked: Float.to_string(parse_float(a["walletBalance"]) - parse_float(a["availableBalance"]))
      }
    end)
  end

  defp parse_balances(_, _, _), do: []

  defp parse_float(nil), do: 0.0
  defp parse_float(str) when is_binary(str) do
    case Float.parse(str) do
      {f, _} -> f
      :error -> 0.0
    end
  end
  defp parse_float(n) when is_number(n), do: n * 1.0
end
