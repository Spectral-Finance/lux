defmodule Lux.Prisms.Binance.Account.GetAccount do
  @moduledoc """
  A prism for fetching Binance account information including balances.

  Returns non-zero balances by default to keep the response concise.

  ## Examples

      iex> GetAccount.handler(%{}, %{name: "Agent"})
      {:ok, %{
        can_trade: true,
        can_withdraw: true,
        can_deposit: true,
        balances: [
          %{asset: "BTC", free: "0.05", locked: "0.01"},
          %{asset: "USDT", free: "1500.00", locked: "0.00"}
        ]
      }}
  """

  use Lux.Prism,
    name: "Binance Get Account",
    description: "Fetches Binance account information and non-zero balances",
    input_schema: %{
      type: :object,
      properties: %{
        all_balances: %{
          type: :boolean,
          description: "Return all balances including zero balances (default: false)"
        },
        api_key: %{type: :string, description: "Binance API key"},
        secret_key: %{type: :string, description: "Binance secret key"}
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        can_trade: %{type: :boolean},
        can_withdraw: %{type: :boolean},
        can_deposit: %{type: :boolean},
        balances: %{
          type: :array,
          description: "List of asset balances"
        }
      },
      required: ["can_trade", "balances"]
    }

  alias Lux.Integrations.Binance.Client
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown"
    Logger.info("Agent #{agent_name} fetching account info")
    all_balances = Map.get(params, :all_balances, false)

    case Client.request(:get, "/api/v3/account", %{
      signed: true,
      api_key: params[:api_key],
      secret_key: params[:secret_key],
      params: %{}
    }) do
      {:ok, account} ->
        balances = account["balances"]
        |> filter_balances(all_balances)

        {:ok, %{
          can_trade: account["canTrade"],
          can_withdraw: account["canWithdraw"],
          can_deposit: account["canDeposit"],
          account_type: account["accountType"],
          balances: balances
        }}

      {:error, {:unauthorized, _code, msg}} ->
        {:error, "Unauthorized: #{msg}"}

      {:error, err} ->
        {:error, "Failed to fetch account: #{inspect(err)}"}
    end
  end

  defp filter_balances(balances, true), do: Enum.map(balances, &parse_balance/1)
  defp filter_balances(balances, false) do
    balances
    |> Enum.filter(fn b -> b["free"] != "0.00000000" or b["locked"] != "0.00000000" end)
    |> Enum.map(&parse_balance/1)
  end

  defp parse_balance(%{"asset" => asset, "free" => free, "locked" => locked}) do
    %{asset: asset, free: free, locked: locked}
  end
end
