defmodule Lux.Prisms.Hyperliquid.HyperliquidSetLeveragePrism do
  @moduledoc """
  A prism that sets leverage for a trading position on the Hyperliquid exchange.

  ## Example

      iex> Lux.Prisms.Hyperliquid.HyperliquidSetLeveragePrism.run(%{
      ...>   coin: "ETH",
      ...>   leverage: 5,
      ...>   is_cross: true,
      ...>   vault_address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5" # Optional
      ...> })
      {:ok,
       %{
         status: "success",
         leverage_result: %{
           "coin" => "ETH",
           "leverage" => 5,
           "is_cross" => true
         }
      }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Prism,
    name: "Hyperliquid Set Leverage",
    description: "Sets leverage for a trading position on Hyperliquid exchange",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
        },
        leverage: %{
          type: :integer,
          description: "Leverage value (1-50)",
          minimum: 1,
          maximum: 50
        },
        is_cross: %{
          type: :boolean,
          description: "True for cross margin, false for isolated margin",
          default: true
        },
        vault_address: %{
          type: :string,
          description: "Optional vault address for leverage setting",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["coin", "leverage"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        leverage_result: %{
          type: :object,
          properties: %{
            coin: %{type: :string},
            leverage: %{type: :integer},
            is_cross: %{type: :boolean}
          },
          required: ["coin", "leverage", "is_cross"]
        }
      },
      required: ["status", "leverage_result"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- {:ok, Config.hyperliquid_account_address()},
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{}} <- import_packages(),
         {:ok, result} <- set_leverage(private_key, address, api_url, input) do
      {:ok, %{status: "success", leverage_result: result}}
    else
      {:error, :missing_private_key} ->
        {:error, "Hyperliquid account private key is not configured"}

      {:error, :missing_api_url} ->
        {:error, "Hyperliquid API URL is not configured"}

      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "Failed to set leverage: #{inspect(reason)}"}
    end
  end

  defp get_private_key do
    {:ok, Config.hyperliquid_account_key()}
  rescue
    RuntimeError -> {:error, :missing_private_key}
  end

  defp import_packages do
    with {:ok, %{}} <- Lux.Python.import_package("hyperliquid.exchange"),
         {:ok, %{}} <- Lux.Python.import_package("hyperliquid_utils.setup") do
      {:ok, %{}}
    end
  end

  defp set_leverage(private_key, address, api_url, params) do
    python_result =
      python variables: %{
               private_key: private_key,
               address: address,
               api_url: api_url,
               params: params
             } do
        ~PY"""
        from hyperliquid.exchange import Exchange
        from hyperliquid_utils.setup import setup

        address, info, exchange = setup(private_key, address, api_url, skip_ws=True)

        # Update exchange instance if vault_address is provided
        if "vault_address" in params:
            exchange = Exchange(
                exchange.wallet,
                exchange.base_url,
                vault_address=params["vault_address"]
            )

        is_cross = params.get("is_cross", True)
        result = exchange.update_leverage(params["leverage"], is_cross, params["coin"])

        {
            "coin": params["coin"],
            "leverage": params["leverage"],
            "is_cross": is_cross
        }
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end