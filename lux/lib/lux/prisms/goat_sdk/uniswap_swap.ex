defmodule Lux.Prisms.GoatSdk.UniswapSwap do
  @moduledoc """
  Implements a swap between two tokens using Uniswap.
  """
  use Lux.Prism,
    name: "Uniswap Swap",
    description: "Implements a swap between two tokens using Uniswap",
    input_schema: %{
      type: :object,
      properties: %{
        from_token: %{
          type: :string,
          description: "Address of the token to swap from"
        },
        to_token: %{
          type: :string,
          description: "Address of the token to swap to"
        },
        amount: %{
          type: :string,
          description: "Amount of tokens to swap"
        },
        chain_id: %{
          type: :integer,
          description: "Chain ID for the swap (e.g. 1 for Ethereum mainnet)",
          default: 1
        },
        slippage: %{
          type: :integer,
          description: "Slippage tolerance in basis points (e.g. 50 for 0.5%)",
          default: 50
        }
      },
      required: ["from_token", "to_token", "amount"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        amount_received: %{
          type: :string,
          description: "Amount of tokens received"
        },
        tx_hash: %{
          type: :string,
          description: "Transaction hash of the swap"
        }
      },
      required: ["amount_received", "tx_hash"]
    }

  import Lux.Python
  require Logger
  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, params} <- validate_params(input) do
      Logger.info("Swapping #{params.amount} from #{params.from_token} to #{params.to_token} on chain #{params.chain_id}")

      with {:ok, %{"success" => true}} <- Lux.Python.import_package("goat_plugins"),
           {:ok, %{"success" => true}} <- Lux.Python.import_package("goat_plugins.uniswap"),
           {:ok, result} <- execute_swap(params) do
        {:ok, result}
      else
        {:ok, %{"success" => false, "error" => error}} ->
          {:error, "Failed to import required packages: #{error}"}

        {:error, reason} ->
          Logger.error("Swap failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp validate_params(input) do
    input = Map.put_new(input, :chain_id, 1)
    input = Map.put_new(input, :slippage, 50)

    required_params = ["from_token", "to_token", "amount"]
    missing_params = Enum.filter(required_params, &(not Map.has_key?(input, String.to_atom(&1))))

    case missing_params do
      [] -> {:ok, input}
      [param | _] -> {:error, "Missing required parameter: #{param}"}
    end
  end

  defp execute_swap(params) do
    api_key = Lux.Config.uniswap_api_key()

    python_result =
      python variables: %{
               from_token: params.from_token,
               to_token: params.to_token,
               amount: params.amount,
               chain_id: params.chain_id,
               slippage: params.slippage,
               api_key: api_key
             } do
        ~PY"""
        result = None
        try:
            from goat_plugins.uniswap import uniswap, UniswapPluginOptions
            from goat_wallets.evm import EVMWalletClient
            import asyncio

            async def run_swap():
                # Initialize the plugin with API key if provided
                options = UniswapPluginOptions(api_key=api_key if api_key else None)
                plugin = uniswap(options)

                # Create a wallet client (this should be replaced with actual wallet)
                wallet_client = EVMWalletClient(chain_id=chain_id)

                # Get swap quote first
                quote_response = await plugin.get_quote(
                    wallet_client,
                    {
                        "tokenIn": from_token,
                        "tokenOut": to_token,
                        "amount": amount
                    }
                )

                # Check token approval
                approval_response = await plugin.check_approval(
                    wallet_client,
                    {
                        "token": from_token,
                        "amount": amount,
                        "walletAddress": wallet_client.get_address()
                    }
                )

                # If approval was needed, wait for it to complete
                if "txHash" in approval_response:
                    # In a real implementation, we would wait for the approval transaction
                    pass

                # Execute the swap
                swap_response = await plugin.swap_tokens(
                    wallet_client,
                    {
                        "tokenIn": from_token,
                        "tokenOut": to_token,
                        "amount": amount
                    }
                )

                return {
                    "amount_received": quote_response["quote"]["amount"],
                    "tx_hash": swap_response["txHash"]
                }

            # Run the async function
            result = asyncio.run(run_swap())
        except Exception as e:
            result = {"error": str(e)}
        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      %{"amount_received" => amount, "tx_hash" => tx_hash} -> {:ok, %{amount_received: amount, tx_hash: tx_hash}}
    end
  end
end
