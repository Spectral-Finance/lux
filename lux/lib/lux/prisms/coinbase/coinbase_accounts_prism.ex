defmodule Lux.Prisms.Coinbase.CoinbaseAccountsPrism do
  @moduledoc """
  A prism that lists Coinbase Exchange accounts (portfolio tracking).

  ## Example

      iex> Lux.Prisms.Coinbase.CoinbaseAccountsPrism.run(%{})
      {:ok,
       %{
         status: "success",
         accounts: [%{"id" => "account-1", "currency" => "USD", "balance" => "1000.00"}]
       }}

  The prism reads authentication details from configuration:
  - :coinbase_api_key - Coinbase Exchange API key
  - :coinbase_secret - base64-encoded Coinbase Exchange API secret
  - :coinbase_passphrase - Coinbase Exchange API passphrase

  See https://docs.cloud.coinbase.com/exchange/reference/exchangerestapi_getaccounts
  """

  use Lux.Prism,
    name: "Coinbase Accounts",
    description: "Lists Coinbase Exchange accounts",
    input_schema: %{
      type: :object,
      properties: %{
        limit: %{
          type: :integer,
          description: "Maximum number of accounts to return"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        accounts: %{type: :object, description: "List of accounts from Coinbase Exchange API"}
      },
      required: ["status", "accounts"]
    }

  alias Lux.Coinbase.Client

  def handler(input, _ctx) do
    with {:ok, params} <- validate(input) do
      path = build_path(params)

      case Client.request(:get, path) do
        {:ok, accounts} ->
          {:ok, %{status: "success", accounts: accounts}}

        {:error, %{"status" => 401}} ->
          {:error, %{code: :unauthorized, reason: "invalid Coinbase API credentials"}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp validate(input) when is_map(input) do
    case Map.get(input, "limit") do
      nil -> {:ok, input}
      limit when is_integer(limit) and limit > 0 -> {:ok, input}
      _ -> {:error, "limit must be an integer greater than 0"}
    end
  end

  defp validate(_input), do: {:error, "input must be a map"}

  defp build_path(%{"limit" => limit}) when is_integer(limit) and limit > 0 do
    "/accounts?limit=#{limit}"
  end

  defp build_path(_params), do: "/accounts"
end
