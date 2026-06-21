defmodule Lux.Prisms.Uniswap.ExecuteSwap do
  @moduledoc """
  Prism for encoding Uniswap V3 swap transactions.
  Supports both exact input and exact output swaps.
  Returns the transaction payload (calldata and router address) ready for broadcasting.
  """

  use Lux.Prism,
    name: "Uniswap.ExecuteSwap",
    description: "Encodes Uniswap V3 swap transaction calldata for exactInputSingle or exactOutputSingle",
    input_schema: %{
      type: :object,
      properties: %{
        token_in: %{
          type: :string,
          description: "Token input contract address"
        },
        token_out: %{
          type: :string,
          description: "Token output contract address"
        },
        fee: %{
          type: :integer,
          description: "Fee tier"
        },
        recipient: %{
          type: :string,
          description: "Recipient of the swap output"
        },
        deadline: %{
          type: :integer,
          description: "Transaction deadline timestamp"
        },
        amount_in: %{
          type: :integer,
          description: "Input amount for exact input swap"
        },
        amount_out: %{
          type: :integer,
          description: "Output amount for exact output swap"
        },
        amount_out_minimum: %{
          type: :integer,
          description: "Minimum output amount (for exact_input swaps)"
        },
        amount_in_maximum: %{
          type: :integer,
          description: "Maximum input amount (for exact_output swaps)"
        },
        sqrt_price_limit_x96: %{
          type: :integer,
          description: "Price limit (optional)",
          default: 0
        },
        swap_type: %{
          type: :string,
          description: "exact_input or exact_output",
          enum: ["exact_input", "exact_output"],
          default: "exact_input"
        },
        network: %{
          type: :string,
          description: "Network to target",
          default: "mainnet"
        }
      },
      required: ["token_in", "token_out", "fee", "recipient"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        to: %{
          type: :string,
          description: "Address of the SwapRouter contract"
        },
        calldata: %{
          type: :string,
          description: "Hex-encoded transaction calldata"
        },
        swap_type: %{
          type: :string,
          description: "The swap type encoded"
        }
      },
      required: ["to", "calldata", "swap_type"]
    }

  alias Lux.Integrations.Uniswap

  @impl true
  def handler(input, _ctx) do
    network = Map.get(input, :network, "mainnet")
    swap_type = Map.get(input, :swap_type, "exact_input")
    deadline = Map.get(input, :deadline) || System.system_time(:second) + 600

    Application.put_env(:lux, Uniswap, network: network)

    router_address = Uniswap.contract_address(:swap_router)

    with {:ok, _} <- Uniswap.validate_address(input.token_in),
         {:ok, _} <- Uniswap.validate_address(input.token_out),
         {:ok, _} <- Uniswap.validate_address(input.recipient),
         {:ok, _} <- Uniswap.validate_fee_tier(input.fee) do
      
      params = %{
        token_in: input.token_in,
        token_out: input.token_out,
        fee: input.fee,
        recipient: input.recipient,
        deadline: deadline,
        sqrt_price_limit_x96: Map.get(input, :sqrt_price_limit_x96, 0)
      }

      case swap_type do
        "exact_input" ->
          amount_in = Map.get(input, :amount_in) || raise "amount_in is required for exact_input"
          amount_out_minimum = Map.get(input, :amount_out_minimum) || 0
          
          full_params = Map.merge(params, %{amount_in: amount_in, amount_out_minimum: amount_out_minimum})
          calldata = Uniswap.encode_exact_input_single(full_params)
          
          {:ok, %{to: router_address, calldata: calldata, swap_type: "exact_input"}}

        "exact_output" ->
          amount_out = Map.get(input, :amount_out) || raise "amount_out is required for exact_output"
          amount_in_maximum = Map.get(input, :amount_in_maximum) || 0

          full_params = Map.merge(params, %{amount_out: amount_out, amount_in_maximum: amount_in_maximum})
          calldata = Uniswap.encode_exact_output_single(full_params)

          {:ok, %{to: router_address, calldata: calldata, swap_type: "exact_output"}}
      end
    end
  end
end
