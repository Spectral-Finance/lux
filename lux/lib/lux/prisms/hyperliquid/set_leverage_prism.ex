defmodule Lux.Prisms.Hyperliquid.SetLeveragePrism do
  @moduledoc """
  A prism that sets leverage for a trading pair on the Hyperliquid exchange.

  Supports both cross and isolated margin modes. Changing leverage affects all
  future positions and modifies existing position margin requirements.

  ## Example

      # Set cross leverage
      iex> Lux.Prisms.Hyperliquid.SetLeveragePrism.run(%{
      ...>   coin: "ETH",
      ...>   leverage: 10,
      ...>   margin_mode: "cross",
      ...>   vault_address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok,
       %{
         status: "success",
         leverage_result: %{
           "coin" => "ETH",
           "leverage" => 10,
           "margin_mode" => "cross",
           "result" => %{
             # ... response from Hyperliquid
           }
         }
      }}

      # Set isolated leverage
      iex> Lux.Prisms.Hyperliquid.SetLeveragePrism.run(%{
      ...>   coin: "BTC",
      ...>   leverage: 5,
      ...>   margin_mode: "isolated"
      ...> })

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Prism,
    name: "Hyperliquid Set Leverage",
    description: "Sets leverage for a trading pair on Hyperliquid exchange",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
        },
        leverage: %{
          type: :integer,
          description: "Leverage multiplier (e.g., 1, 2, 5, 10, 20, 50)"
        },
        margin_mode: %{
          type: :string,
          description: "Margin mode: 'cross' or 'isolated'",
          enum: ["cross", "isolated"],
          default: "cross"
        },
        vault_address: %{
          type: :string,
          description: "Optional vault address",
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
            margin_mode: %{type: :string},
            result: %{type: :object}
          },
          required: ["coin", "leverage", "margin_mode", "result"]
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
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.exchange"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- set_leverage(private_key, address, api_url, input) do
      {:ok, %{status: "success", leverage_result: result}}
    else
      {:error, :missing_private_key} ->
        {:error, "Hyperliquid account private key is not configured"}

      {:error, :missing_api_url} ->
        {:error, "Hyperliquid API URL is not configured"}

      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import required packages: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_private_key do
    {:ok, Config.hyperliquid_account_key()}
  rescue
    RuntimeError -> {:error, :missing_private_key}
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

        margin_mode = params.get("margin_mode", "cross")
        is_cross = margin_mode == "cross"

        result = exchange.update_leverage(
            leverage=params["leverage"],
            name=params["coin"],
            is_cross=is_cross
        )

        {
            "coin": params["coin"],
            "leverage": params["leverage"],
            "margin_mode": margin_mode,
            "result": result
        }
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end
