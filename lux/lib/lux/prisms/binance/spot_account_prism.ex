defmodule Lux.Prisms.Binance.SpotAccountPrism do
  @moduledoc """
  A Prism that retrieves Binance Spot account details, permissions, and asset balances.

  ## Examples

      iex> Lux.Prisms.Binance.SpotAccountPrism.run(%{api_key: "key", secret_key: "secret"})
      {:ok, %{"accountType" => "SPOT", "balances" => [%{"asset" => "BTC", "free" => "1.0", "locked" => "0.0"}]}}
  """

  use Lux.Prism,
    name: "Binance Spot Account Prism",
    description: "Retrieves Spot account balances, permissions, and status from Binance.",
    input_schema: %{
      type: :object,
      properties: %{
        recv_window: %{type: :integer, default: 5000, description: "Receive window in milliseconds"},
        api_key: %{type: :string, description: "Binance API Key"},
        secret_key: %{type: :string, description: "Binance Secret Key"},
        testnet: %{type: :boolean, default: false, description: "Whether to use Binance testnet"}
      }
    }

  alias Lux.Binance.Client

  def handler(input, context) do
    opts = build_opts(input, context)

    case Client.request(:get, :spot, "/api/v3/account", %{}, opts) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_opts(input, context) do
    ctx = context || %{}
    recv_window = Map.get(input, :recv_window) || Map.get(input, "recv_window", 5000)
    api_key = Map.get(input, :api_key) || Map.get(input, "api_key") || Map.get(ctx, :api_key)
    secret_key = Map.get(input, :secret_key) || Map.get(input, "secret_key") || Map.get(ctx, :secret_key)
    testnet? = Map.get(input, :testnet) || Map.get(input, "testnet", false) || Map.get(ctx, :testnet, false)
    req_options = Map.get(input, :req_options) || Map.get(ctx, :req_options, [])

    [
      signed: true,
      api_key: api_key,
      secret_key: secret_key,
      testnet: testnet?,
      recv_window: recv_window,
      req_options: req_options
    ]
  end
end
