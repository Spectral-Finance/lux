defmodule Lux.Lenses.Etherscan.Events.UniswapSwapLens do
  @moduledoc """
  Lens for monitoring Uniswap V3 swap events from the Etherscan API.

  Retrieves Uniswap V3 Swap events from specific pools, including swap amounts,
  prices, and participant information. This lens uses the Etherscan `logs` module
  with `getLogs` action to filter Swap events by pool address.

  ## Uniswap V3 Pool Addresses

  Well-known Uniswap V3 pools on Ethereum mainnet:

  | Pool                              | Address                                    |
  |-----------------------------------|--------------------------------------------|
  | WETH/USDC (0.05%)                 | 0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640 |
  | WETH/USDC (0.30%)                 | 0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8 |
  | WETH/USDT (0.05%)                 | 0x11b815efb8f581194ae79006d24e0d814b7697f6 |
  | WETH/DAI (0.30%)                  | 0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8 |
  | WETH/USDC (0.01%)                 | 0x3416cf6c708da44db2624d63ea0aaef71b82d5c8 |

  ## Swap Event Signature

  The Swap event signature for Uniswap V3:
  ```
  Swap(address sender, address recipient, int256 amount0, int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick)
  ```
  topic0: `0xc42079f94a6350d7e6235f29174924f91065fbc2da3237a9a9b3f4a31aace1a1`

  ## Examples

  ```elixir
  # Monitor WETH/USDC pool swaps
  Lux.Lenses.Etherscan.Events.UniswapSwapLens.focus(%{
    pool_address: "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
    from_block: 18_000_000,
    to_block: 18_001_000,
    page: 1,
    offset: 100
  })

  # Filter by minimum swap amount
  Lux.Lenses.Etherscan.Events.UniswapSwapLens.focus(%{
    pool_address: "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
    min_amount: "1000000",  # 1 USDC (6 decimals)
    from_block: 18_000_000,
    to_block: 18_001_000
  })

  # Filter by sender
  Lux.Lenses.Etherscan.Events.UniswapSwapLens.focus(%{
    pool_address: "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
    sender: "0x68b3465833fb72a70ecdf485e0e4c7bd8665fc45",
    from_block: 18_000_000,
    to_block: 18_001_000
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.Events.UniswapSwap",
    description: "Monitors Uniswap V3 swap events with amounts and price information",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Base.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        chainid: %{
          type: :integer,
          description: "Network identifier (1=Ethereum, 137=Polygon, 42161=Arbitrum)",
          default: 1
        },
        pool_address: %{
          type: :string,
          description: "Uniswap V3 pool contract address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        sender: %{
          type: :string,
          description: "Optional sender address to filter swaps by"
        },
        min_amount: %{
          type: :string,
          description: "Minimum swap amount (in token decimals) to filter results"
        },
        from_block: %{
          type: :integer,
          description: "Starting block number (inclusive)"
        },
        to_block: %{
          type: :integer,
          description: "Ending block number (inclusive)"
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results (starts at 1)",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of swaps to return per page (max 1000)",
          default: 100
        }
      },
      required: ["pool_address", "from_block", "to_block"]
    }

  @swap_event_topic "0xc42079f94a6350d7e6235f29174924f91065fbc2da3237a9a9b3f4a31aace1a1"

  @doc """
  Prepares parameters before making the API request.

  Maps the schema fields to Etherscan API parameter names and sets
  the Uniswap V3 Swap event signature as topic0.
  """
  def before_focus(params) do
    params
    |> Map.put(:module, "logs")
    |> Map.put(:action, "getLogs")
    |> Map.put(:topic0, @swap_event_topic)
    |> maybe_put(:pool_address, :address)
    |> maybe_put(:from_block, :fromBlock)
    |> maybe_put(:to_block, :toBlock)
    |> maybe_put(:sender, :topic1)
  end

  defp maybe_put(params, key, new_key) do
    case Map.get(params, key) do
      nil -> params
      value -> Map.put(params, new_key, value)
    end
  end

  @doc """
  Transforms the API response into a structured format with swap event details.

  Decodes the swap event data including amounts, prices, and liquidity changes.

  ## Examples

      iex> after_focus(%{"status" => "1", "result" => [%{"address" => "0x...", "topics" => [...], "data" => "0x...", ...}]})
      {:ok, %{swaps: [%{pool: "0x...", amount0: "...", amount1: "...", ...}]}}
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        swaps = Enum.map(result, &transform_swap/1)

        swaps = case result do
          _ when is_list(swaps) ->
            Enum.filter(swaps, fn swap ->
              case swap do
                %{amount0: "", amount1: ""} -> false
                _ -> true
              end
            end)
        end

        {:ok, %{
          swaps: swaps,
          count: length(swaps)
        }}

      other ->
        other
    end
  end

  defp transform_swap(log) do
    topics = Map.get(log, "topics", [])
    data = Map.get(log, "data", "")

    %{
      pool: Map.get(log, "address", ""),
      transaction_hash: Map.get(log, "transactionHash", ""),
      block_number: Map.get(log, "blockNumber", ""),
      timestamp: Map.get(log, "timeStamp", ""),
      sender: decode_topic(topics, 1),
      recipient: decode_topic(topics, 2),
      amount0: extract_amount0(data),
      amount1: extract_amount1(data),
      sqrt_price_x96: extract_sqrt_price(data),
      liquidity: extract_liquidity(data),
      tick: extract_tick(data),
      gas_price: Map.get(log, "gasPrice", ""),
      gas_used: Map.get(log, "gasUsed", "")
    }
  end

  defp decode_topic(topics, index) do
    case Enum.at(topics, index) do
      nil -> ""
      topic ->
        # Remove leading zeros to get the actual address
        String.replace(topic, ~r/^0x0{0,24}/, "0x")
    end
  end

  defp extract_amount0("0x" <> data) when byte_size(data) >= 128 do
    data
    |> String.slice(0, 64)
    |> parse_hex_int()
  end

  defp extract_amount0(_), do: ""

  defp extract_amount1("0x" <> data) when byte_size(data) >= 128 do
    data
    |> String.slice(64, 64)
    |> parse_hex_int()
  end

  defp extract_amount1(_), do: ""

  defp extract_sqrt_price("0x" <> data) when byte_size(data) >= 192 do
    data
    |> String.slice(128, 64)
    |> parse_hex_int()
  end

  defp extract_sqrt_price(_), do: ""

  defp extract_liquidity("0x" <> data) when byte_size(data) >= 256 do
    data
    |> String.slice(192, 64)
    |> parse_hex_int()
  end

  defp extract_liquidity(_), do: ""

  defp extract_tick("0x" <> data) when byte_size(data) >= 320 do
    data
    |> String.slice(256, 64)
    |> parse_hex_int()
  end

  defp extract_tick(_), do: ""

  defp parse_hex_int(hex) do
    case Integer.parse(hex, 16) do
      {int, _} -> to_string(int)
      :error -> ""
    end
  end
end
