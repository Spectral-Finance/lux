# lib/lux/prisms/goat_sdk/uniswap_swap.ex
defmodule Lux.Prisms.GoatSdk.UniswapSwap do
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
        }
      },
      required: ["amount_received"]
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
        {:ok, %{amount_received: result}}
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
    python_result =
      python variables: %{
               from_token: params.from_token,
               to_token: params.to_token,
               amount: params.amount,
               chain_id: params.chain_id,
               slippage: params.slippage
             } do
        ~PY"""
        result = None
        try:
            from goat_plugins.uniswap import uniswap, UniswapPluginOptions

            # Get swap quote first
            quote = uniswap.get_swap_quote(
                chain_id=chain_id,
                token_in=from_token,
                token_out=to_token,
                amount=amount,
                slippage=slippage
            )

            # Execute the swap
            result = uniswap.execute_swap(quote)

            # Return the amount received
            result = result["amount_received"]
        except Exception as e:
            result = {"error": str(e)}
        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_binary(result) -> {:ok, result}
    end
  end
end
