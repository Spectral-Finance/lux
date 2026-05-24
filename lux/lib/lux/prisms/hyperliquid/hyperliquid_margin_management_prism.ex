defmodule Lux.Prisms.Hyperliquid.HyperliquidMarginManagementPrism do
  @moduledoc """
  A prism that manages margin for Hyperliquid positions (add or remove margin).

  ## Example

      # Add margin to a position
      iex> Lux.Prisms.Hyperliquid.HyperliquidMarginManagementPrism.run(%{
      ...>   coin: "ETH",
      ...>   amount: 100.0,
      ...>   action: "add",
      ...>   vault_address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5" # Optional
      ...> })
      {:ok,
       %{
         status: "success",
         margin_result: %{
           "coin" => "ETH",
           "action" => "add",
           "amount" => 100.0
         }
      }}

      # Remove margin from a position
      iex> Lux.Prisms.Hyperliquid.HyperliquidMarginManagementPrism.run(%{
      ...>   coin: "ETH",
      ...>   amount: 50.0,
      ...>   action: "remove"
      ...> })
      {:ok,
       %{
         status: "success",
         margin_result: %{
           "coin" => "ETH",
           "action" => "remove",
           "amount" => 50.0
         }
      }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Prism,
    name: "Hyperliquid Margin Management",
    description: "Adds or removes margin from Hyperliquid positions",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
        },
        amount: %{
          type: :number,
          description: "Amount of margin to add or remove in USD"
        },
        action: %{
          type: :string,
          description: "Whether to add or remove margin",
          enum: ["add", "remove"]
        },
        vault_address: %{
          type: :string,
          description: "Optional vault address for margin management",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["coin", "amount", "action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        margin_result: %{
          type: :object,
          properties: %{
            coin: %{type: :string},
            action: %{type: :string},
            amount: %{type: :number}
          },
          required: ["coin", "action", "amount"]
        }
      },
      required: ["status", "margin_result"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- {:ok, Config.hyperliquid_account_address()},
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{}} <- import_packages(),
         {:ok, result} <- manage_margin(private_key, address, api_url, input) do
      {:ok, %{status: "success", margin_result: result}}
    else
      {:error, :missing_private_key} ->
        {:error, "Hyperliquid account private key is not configured"}

      {:error, :missing_api_url} ->
        {:error, "Hyperliquid API URL is not configured"}

      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "Failed to manage margin: #{inspect(reason)}"}
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

  defp manage_margin(private_key, address, api_url, params) do
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

        coin = params["coin"]
        amount = float(params["amount"])
        is_add = params["action"] == "add"

        result = exchange.update_isolated_margin(coin, is_add, amount)

        {
            "coin": coin,
            "action": params["action"],
            "amount": amount
        }
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end