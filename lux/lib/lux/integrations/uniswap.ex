defmodule Lux.Integrations.Uniswap do
  @moduledoc """
  Integration with Uniswap V3 for decentralized exchange operations and liquidity management.

  Provides on-chain interaction with Uniswap V3 contracts including:
  - SwapRouter: Token swaps with exact input/output
  - Factory: Pool creation and discovery
  - Pool: Price and liquidity data
  - NonfungiblePositionManager: Liquidity position management

  ## Configuration

  The following configuration is required in your `config/runtime.exs`:

      config :lux, Lux.Integrations.Uniswap,
        network: System.get_env("UNISWAP_NETWORK") || "mainnet",
        rpc_url: System.get_env("ETH_RPC_URL")

  And in your environment file (e.g., `dev.envrc` or `test.envrc`):

      ETH_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/your-api-key"
      UNISWAP_NETWORK="mainnet"  # Optional, defaults to "mainnet"

  ## Supported Networks

  - `"mainnet"` — Ethereum mainnet
  - `"goerli"` — Goerli testnet
  - `"sepolia"` — Sepolia testnet
  - `"arbitrum"` — Arbitrum One
  - `"optimism"` — Optimism
  - `"polygon"` — Polygon PoS
  - `"base"` — Base

  ## Contract Addresses

  All contract addresses are sourced from the official Uniswap V3 deployments.

  ## Usage Examples

      alias Lux.Integrations.Uniswap

      # Get pool address for WETH/USDC with 0.3% fee
      {:ok, pool_address} = Uniswap.get_pool(
        "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",  # WETH
        "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",  # USDC
        3000  # 0.3% fee tier
      )

      # Get current network config
      config = Uniswap.network_config()

      # Encode a swap call
      calldata = Uniswap.encode_exact_input_single(swap_params)
  """

  require Logger

  # ─── Contract Addresses (Ethereum Mainnet) ───────────────────────────────

  @contract_addresses %{
    "mainnet" => %{
      swap_router: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
      swap_router_02: "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45",
      factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
      nonfungible_position_manager: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
      quoter: "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6",
      quoter_v2: "0x61fFE014bA17989E743c5F6cB21bF9697530B21e",
      weth: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    },
    "goerli" => %{
      swap_router: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
      swap_router_02: "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45",
      factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
      nonfungible_position_manager: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
      quoter: "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6",
      quoter_v2: "0x61fFE014bA17989E743c5F6cB21bF9697530B21e",
      weth: "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6"
    },
    "sepolia" => %{
      swap_router: "0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E",
      swap_router_02: "0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E",
      factory: "0x0227628f3F023bb0B980b67D528571c95c6DaC1c",
      nonfungible_position_manager: "0x1238536071E1c677A632429e3655c799b22cDA52",
      quoter: "0xEd1f6473345F45b75F8179591dd5bA1888516863",
      quoter_v2: "0xEd1f6473345F45b75F8179591dd5bA1888516863",
      weth: "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14"
    },
    "arbitrum" => %{
      swap_router: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
      swap_router_02: "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45",
      factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
      nonfungible_position_manager: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
      quoter: "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6",
      quoter_v2: "0x61fFE014bA17989E743c5F6cB21bF9697530B21e",
      weth: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
    },
    "optimism" => %{
      swap_router: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
      swap_router_02: "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45",
      factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
      nonfungible_position_manager: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
      quoter: "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6",
      quoter_v2: "0x61fFE014bA17989E743c5F6cB21bF9697530B21e",
      weth: "0x4200000000000000000000000000000000000006"
    },
    "polygon" => %{
      swap_router: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
      swap_router_02: "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45",
      factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
      nonfungible_position_manager: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
      quoter: "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6",
      quoter_v2: "0x61fFE014bA17989E743c5F6cB21bF9697530B21e",
      weth: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"
    },
    "base" => %{
      swap_router: "0x2626664c2603336E57B271c5C0b26F421741e481",
      swap_router_02: "0x2626664c2603336E57B271c5C0b26F421741e481",
      factory: "0x33128a8fC17869897dcE68Ed026d694621f6FDfD",
      nonfungible_position_manager: "0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1",
      quoter: "0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a",
      quoter_v2: "0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a",
      weth: "0x4200000000000000000000000000000000000006"
    }
  }

  # ─── Fee Tiers ──────────────────────────────────────────────────────────

  @fee_tiers [100, 500, 3000, 10_000]
  @fee_tier_labels %{
    100 => "0.01%",
    500 => "0.05%",
    3000 => "0.3%",
    10_000 => "1%"
  }

  # ─── ABI Fragments ─────────────────────────────────────────────────────

  @factory_abi [
    %{
      "name" => "getPool",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [
        %{"name" => "tokenA", "type" => "address"},
        %{"name" => "tokenB", "type" => "address"},
        %{"name" => "fee", "type" => "uint24"}
      ],
      "outputs" => [%{"name" => "pool", "type" => "address"}]
    }
  ]

  @pool_abi [
    %{
      "name" => "slot0",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [],
      "outputs" => [
        %{"name" => "sqrtPriceX96", "type" => "uint160"},
        %{"name" => "tick", "type" => "int24"},
        %{"name" => "observationIndex", "type" => "uint16"},
        %{"name" => "observationCardinality", "type" => "uint16"},
        %{"name" => "observationCardinalityNext", "type" => "uint16"},
        %{"name" => "feeProtocol", "type" => "uint8"},
        %{"name" => "unlocked", "type" => "bool"}
      ]
    },
    %{
      "name" => "liquidity",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [],
      "outputs" => [%{"name" => "", "type" => "uint128"}]
    },
    %{
      "name" => "token0",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [],
      "outputs" => [%{"name" => "", "type" => "address"}]
    },
    %{
      "name" => "token1",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [],
      "outputs" => [%{"name" => "", "type" => "address"}]
    },
    %{
      "name" => "fee",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [],
      "outputs" => [%{"name" => "", "type" => "uint24"}]
    },
    %{
      "name" => "tickSpacing",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [],
      "outputs" => [%{"name" => "", "type" => "int24"}]
    },
    %{
      "name" => "ticks",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [%{"name" => "tick", "type" => "int24"}],
      "outputs" => [
        %{"name" => "liquidityGross", "type" => "uint128"},
        %{"name" => "liquidityNet", "type" => "int128"},
        %{"name" => "feeGrowthOutside0X128", "type" => "uint256"},
        %{"name" => "feeGrowthOutside1X128", "type" => "uint256"},
        %{"name" => "tickCumulativeOutside", "type" => "int56"},
        %{"name" => "secondsPerLiquidityOutsideX128", "type" => "uint160"},
        %{"name" => "secondsOutside", "type" => "uint32"},
        %{"name" => "initialized", "type" => "bool"}
      ]
    }
  ]

  @position_manager_abi [
    %{
      "name" => "positions",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [%{"name" => "tokenId", "type" => "uint256"}],
      "outputs" => [
        %{"name" => "nonce", "type" => "uint96"},
        %{"name" => "operator", "type" => "address"},
        %{"name" => "token0", "type" => "address"},
        %{"name" => "token1", "type" => "address"},
        %{"name" => "fee", "type" => "uint24"},
        %{"name" => "tickLower", "type" => "int24"},
        %{"name" => "tickUpper", "type" => "int24"},
        %{"name" => "liquidity", "type" => "uint128"},
        %{"name" => "feeGrowthInside0LastX128", "type" => "uint256"},
        %{"name" => "feeGrowthInside1LastX128", "type" => "uint256"},
        %{"name" => "tokensOwed0", "type" => "uint128"},
        %{"name" => "tokensOwed1", "type" => "uint128"}
      ]
    },
    %{
      "name" => "balanceOf",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [%{"name" => "owner", "type" => "address"}],
      "outputs" => [%{"name" => "balance", "type" => "uint256"}]
    },
    %{
      "name" => "tokenOfOwnerByIndex",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [
        %{"name" => "owner", "type" => "address"},
        %{"name" => "index", "type" => "uint256"}
      ],
      "outputs" => [%{"name" => "tokenId", "type" => "uint256"}]
    },
    %{
      "name" => "mint",
      "type" => "function",
      "stateMutability" => "payable",
      "inputs" => [
        %{
          "name" => "params",
          "type" => "tuple",
          "components" => [
            %{"name" => "token0", "type" => "address"},
            %{"name" => "token1", "type" => "address"},
            %{"name" => "fee", "type" => "uint24"},
            %{"name" => "tickLower", "type" => "int24"},
            %{"name" => "tickUpper", "type" => "int24"},
            %{"name" => "amount0Desired", "type" => "uint256"},
            %{"name" => "amount1Desired", "type" => "uint256"},
            %{"name" => "amount0Min", "type" => "uint256"},
            %{"name" => "amount1Min", "type" => "uint256"},
            %{"name" => "recipient", "type" => "address"},
            %{"name" => "deadline", "type" => "uint256"}
          ]
        }
      ],
      "outputs" => [
        %{"name" => "tokenId", "type" => "uint256"},
        %{"name" => "liquidity", "type" => "uint128"},
        %{"name" => "amount0", "type" => "uint256"},
        %{"name" => "amount1", "type" => "uint256"}
      ]
    },
    %{
      "name" => "decreaseLiquidity",
      "type" => "function",
      "stateMutability" => "payable",
      "inputs" => [
        %{
          "name" => "params",
          "type" => "tuple",
          "components" => [
            %{"name" => "tokenId", "type" => "uint256"},
            %{"name" => "liquidity", "type" => "uint128"},
            %{"name" => "amount0Min", "type" => "uint256"},
            %{"name" => "amount1Min", "type" => "uint256"},
            %{"name" => "deadline", "type" => "uint256"}
          ]
        }
      ],
      "outputs" => [
        %{"name" => "amount0", "type" => "uint256"},
        %{"name" => "amount1", "type" => "uint256"}
      ]
    },
    %{
      "name" => "collect",
      "type" => "function",
      "stateMutability" => "payable",
      "inputs" => [
        %{
          "name" => "params",
          "type" => "tuple",
          "components" => [
            %{"name" => "tokenId", "type" => "uint256"},
            %{"name" => "recipient", "type" => "address"},
            %{"name" => "amount0Max", "type" => "uint128"},
            %{"name" => "amount1Max", "type" => "uint128"}
          ]
        }
      ],
      "outputs" => [
        %{"name" => "amount0", "type" => "uint256"},
        %{"name" => "amount1", "type" => "uint256"}
      ]
    }
  ]

  @swap_router_abi [
    %{
      "name" => "exactInputSingle",
      "type" => "function",
      "stateMutability" => "payable",
      "inputs" => [
        %{
          "name" => "params",
          "type" => "tuple",
          "components" => [
            %{"name" => "tokenIn", "type" => "address"},
            %{"name" => "tokenOut", "type" => "address"},
            %{"name" => "fee", "type" => "uint24"},
            %{"name" => "recipient", "type" => "address"},
            %{"name" => "deadline", "type" => "uint256"},
            %{"name" => "amountIn", "type" => "uint256"},
            %{"name" => "amountOutMinimum", "type" => "uint256"},
            %{"name" => "sqrtPriceLimitX96", "type" => "uint160"}
          ]
        }
      ],
      "outputs" => [%{"name" => "amountOut", "type" => "uint256"}]
    },
    %{
      "name" => "exactOutputSingle",
      "type" => "function",
      "stateMutability" => "payable",
      "inputs" => [
        %{
          "name" => "params",
          "type" => "tuple",
          "components" => [
            %{"name" => "tokenIn", "type" => "address"},
            %{"name" => "tokenOut", "type" => "address"},
            %{"name" => "fee", "type" => "uint24"},
            %{"name" => "recipient", "type" => "address"},
            %{"name" => "deadline", "type" => "uint256"},
            %{"name" => "amountOut", "type" => "uint256"},
            %{"name" => "amountInMaximum", "type" => "uint256"},
            %{"name" => "sqrtPriceLimitX96", "type" => "uint160"}
          ]
        }
      ],
      "outputs" => [%{"name" => "amountIn", "type" => "uint256"}]
    }
  ]

  @quoter_abi [
    %{
      "name" => "quoteExactInputSingle",
      "type" => "function",
      "stateMutability" => "nonpayable",
      "inputs" => [
        %{"name" => "tokenIn", "type" => "address"},
        %{"name" => "tokenOut", "type" => "address"},
        %{"name" => "fee", "type" => "uint24"},
        %{"name" => "amountIn", "type" => "uint256"},
        %{"name" => "sqrtPriceLimitX96", "type" => "uint160"}
      ],
      "outputs" => [%{"name" => "amountOut", "type" => "uint256"}]
    },
    %{
      "name" => "quoteExactOutputSingle",
      "type" => "function",
      "stateMutability" => "nonpayable",
      "inputs" => [
        %{"name" => "tokenIn", "type" => "address"},
        %{"name" => "tokenOut", "type" => "address"},
        %{"name" => "fee", "type" => "uint24"},
        %{"name" => "amountOut", "type" => "uint256"},
        %{"name" => "sqrtPriceLimitX96", "type" => "uint160"}
      ],
      "outputs" => [%{"name" => "amountIn", "type" => "uint256"}]
    }
  ]

  # ─── Public API ─────────────────────────────────────────────────────────

  @doc """
  Returns the configured network name.
  Defaults to "mainnet" if not configured.
  """
  @spec network() :: String.t()
  def network do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:network, "mainnet")
  end

  @doc """
  Returns the configured RPC URL for Ethereum JSON-RPC calls.
  Falls back to Alchemy API key if ETH_RPC_URL is not set.
  """
  @spec rpc_url() :: String.t()
  def rpc_url do
    config = Application.get_env(:lux, __MODULE__, [])

    case Keyword.get(config, :rpc_url) do
      nil ->
        api_key = Lux.Config.alchemy_api_key()
        network_name = network()
        alchemy_network = alchemy_network_slug(network_name)
        "https://#{alchemy_network}.g.alchemy.com/v2/#{api_key}"

      url ->
        url
    end
  end

  @doc """
  Returns the full contract addresses map for the configured network.
  """
  @spec network_config() :: map()
  def network_config do
    Map.get(@contract_addresses, network(), @contract_addresses["mainnet"])
  end

  @doc """
  Returns the contract address for a specific contract on the configured network.
  """
  @spec contract_address(atom()) :: String.t()
  def contract_address(contract_name) do
    config = network_config()
    Map.get(config, contract_name)
  end

  @doc """
  Returns all supported fee tiers for Uniswap V3 pools.
  """
  @spec fee_tiers() :: [integer()]
  def fee_tiers, do: @fee_tiers

  @doc """
  Returns a human-readable label for a fee tier.
  """
  @spec fee_tier_label(integer()) :: String.t()
  def fee_tier_label(fee), do: Map.get(@fee_tier_labels, fee, "#{fee / 10_000}%")

  @doc """
  Returns the Factory contract ABI.
  """
  @spec factory_abi() :: list()
  def factory_abi, do: @factory_abi

  @doc """
  Returns the Pool contract ABI.
  """
  @spec pool_abi() :: list()
  def pool_abi, do: @pool_abi

  @doc """
  Returns the NonfungiblePositionManager contract ABI.
  """
  @spec position_manager_abi() :: list()
  def position_manager_abi, do: @position_manager_abi

  @doc """
  Returns the SwapRouter contract ABI.
  """
  @spec swap_router_abi() :: list()
  def swap_router_abi, do: @swap_router_abi

  @doc """
  Returns the Quoter contract ABI.
  """
  @spec quoter_abi() :: list()
  def quoter_abi, do: @quoter_abi

  @doc """
  Validates a fee tier value.
  """
  @spec validate_fee_tier(integer()) :: {:ok, integer()} | {:error, String.t()}
  def validate_fee_tier(fee) when fee in @fee_tiers, do: {:ok, fee}

  def validate_fee_tier(fee) do
    {:error, "Invalid fee tier: #{fee}. Valid tiers: #{inspect(@fee_tiers)}"}
  end

  @doc """
  Validates an Ethereum address format.
  """
  @spec validate_address(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_address(address) when is_binary(address) do
    if Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address) do
      {:ok, address}
    else
      {:error, "Invalid Ethereum address: #{address}"}
    end
  end

  def validate_address(_), do: {:error, "Address must be a string"}

  @doc """
  Converts a sqrtPriceX96 value to a human-readable price.

  The sqrtPriceX96 is the square root of the price ratio (token1/token0)
  multiplied by 2^96.
  """
  @spec sqrt_price_x96_to_price(integer(), integer(), integer()) :: float()
  def sqrt_price_x96_to_price(sqrt_price_x96, decimals0 \\ 18, decimals1 \\ 18) do
    price_ratio = :math.pow(sqrt_price_x96 / :math.pow(2, 96), 2)
    price_ratio * :math.pow(10, decimals0 - decimals1)
  end

  @doc """
  Converts a tick value to a price.
  """
  @spec tick_to_price(integer(), integer(), integer()) :: float()
  def tick_to_price(tick, decimals0 \\ 18, decimals1 \\ 18) do
    :math.pow(1.0001, tick) * :math.pow(10, decimals0 - decimals1)
  end

  @doc """
  Converts a price to the nearest valid tick for a given tick spacing.
  """
  @spec price_to_tick(float(), integer()) :: integer()
  def price_to_tick(price, tick_spacing \\ 60) do
    raw_tick = round(:math.log(price) / :math.log(1.0001))
    div(raw_tick, tick_spacing) * tick_spacing
  end

  @doc """
  Returns all supported network names.
  """
  @spec supported_networks() :: [String.t()]
  def supported_networks, do: Map.keys(@contract_addresses)

  @doc """
  Checks if a network is supported.
  """
  @spec network_supported?(String.t()) :: boolean()
  def network_supported?(network_name) do
    Map.has_key?(@contract_addresses, network_name)
  end

  @doc """
  Encodes an eth_call request payload for a contract function.
  """
  @spec encode_eth_call(String.t(), String.t()) :: map()
  def encode_eth_call(to, data) do
    %{
      "jsonrpc" => "2.0",
      "method" => "eth_call",
      "params" => [
        %{"to" => to, "data" => data},
        "latest"
      ],
      "id" => 1
    }
  end

  @doc """
  Encodes a function selector from a function name and parameter types.

  ## Example

      iex> Lux.Integrations.Uniswap.encode_function_selector("getPool", ["address", "address", "uint24"])
      "0x1698ee82"
  """
  @spec encode_function_selector(String.t(), [String.t()]) :: String.t()
  def encode_function_selector(function_name, param_types) do
    signature = "#{function_name}(#{Enum.join(param_types, ",")})"
    hash = ExKeccak.hash_256(signature)
    "0x" <> Base.encode16(binary_part(hash, 0, 4), case: :lower)
  end

  @doc """
  Pads an address to 32 bytes for ABI encoding.
  """
  @spec pad_address(String.t()) :: String.t()
  def pad_address("0x" <> address) do
    String.pad_leading(String.downcase(address), 64, "0")
  end

  @doc """
  Pads a uint256 value to 32 bytes for ABI encoding.
  """
  @spec pad_uint256(integer()) :: String.t()
  def pad_uint256(value) when is_integer(value) do
    value
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(64, "0")
  end

  @doc """
  Pads a uint24 value to 32 bytes for ABI encoding.
  """
  @spec pad_uint24(integer()) :: String.t()
  def pad_uint24(value) when is_integer(value) do
    pad_uint256(value)
  end

  @doc """
  Decodes a hex string result from an eth_call.
  """
  @spec decode_hex(String.t()) :: integer()
  def decode_hex("0x" <> hex) do
    {value, _} = Integer.parse(hex, 16)
    value
  end

  def decode_hex(""), do: 0

  def decode_hex(hex) when is_binary(hex) do
    {value, _} = Integer.parse(hex, 16)
    value
  end

  @doc """
  Decodes an address from a 32-byte ABI-encoded hex string.
  """
  @spec decode_address(String.t()) :: String.t()
  def decode_address(hex_data) when byte_size(hex_data) >= 40 do
    address_hex = String.slice(hex_data, -40, 40)
    "0x" <> address_hex
  end

  @doc """
  Makes a JSON-RPC call to the configured Ethereum node.
  """
  @spec eth_call(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def eth_call(to, data) do
    payload = encode_eth_call(to, data)
    req_opts = [json: payload] ++ Application.get_env(:lux, :req_options, [])

    case Req.post(rpc_url(), req_opts) do
      {:ok, %{status: 200, body: %{"result" => result}}} ->
        {:ok, result}

      {:ok, %{status: 200, body: %{"error" => error}}} ->
        {:error, error}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the pool address for a token pair and fee tier from the Factory contract.
  """
  @spec get_pool(String.t(), String.t(), integer()) :: {:ok, String.t()} | {:error, term()}
  def get_pool(token_a, token_b, fee) do
    factory = contract_address(:factory)
    selector = encode_function_selector("getPool", ["address", "address", "uint24"])
    data = selector <> pad_address(token_a) <> pad_address(token_b) <> pad_uint24(fee)

    case eth_call(factory, data) do
      {:ok, "0x" <> result} ->
        address = decode_address(result)

        if address == "0x0000000000000000000000000000000000000000" do
          {:error, "Pool not found for the given token pair and fee tier"}
        else
          {:ok, address}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the slot0 data from a pool contract (current price, tick, etc.).
  """
  @spec get_pool_slot0(String.t()) :: {:ok, map()} | {:error, term()}
  def get_pool_slot0(pool_address) do
    selector = encode_function_selector("slot0", [])

    case eth_call(pool_address, selector) do
      {:ok, "0x" <> result} ->
        # slot0 returns 7 values, each 32 bytes (64 hex chars)
        sqrt_price_x96 = decode_hex("0x" <> String.slice(result, 0, 64))
        tick = decode_signed_int("0x" <> String.slice(result, 64, 64), 256)

        {:ok,
         %{
           sqrt_price_x96: sqrt_price_x96,
           tick: tick,
           observation_index: decode_hex("0x" <> String.slice(result, 128, 64)),
           observation_cardinality: decode_hex("0x" <> String.slice(result, 192, 64)),
           observation_cardinality_next: decode_hex("0x" <> String.slice(result, 256, 64)),
           fee_protocol: decode_hex("0x" <> String.slice(result, 320, 64)),
           unlocked: decode_hex("0x" <> String.slice(result, 384, 64)) == 1
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the current liquidity of a pool.
  """
  @spec get_pool_liquidity(String.t()) :: {:ok, integer()} | {:error, term()}
  def get_pool_liquidity(pool_address) do
    selector = encode_function_selector("liquidity", [])

    case eth_call(pool_address, selector) do
      {:ok, result} ->
        {:ok, decode_hex(result)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Queries all Uniswap V3 positions owned by an address.
  """
  @spec get_liquidity_positions(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_liquidity_positions(owner) do
    pm = contract_address(:nonfungible_position_manager)
    balance_selector = encode_function_selector("balanceOf", ["address"])
    balance_data = balance_selector <> pad_address(owner)

    case eth_call(pm, balance_data) do
      {:ok, balance_hex} ->
        balance = decode_hex(balance_hex)
        if balance > 0 do
          positions =
            Enum.map(0..(balance - 1), fn index ->
              token_id_selector = encode_function_selector("tokenOfOwnerByIndex", ["address", "uint256"])
              token_id_data = token_id_selector <> pad_address(owner) <> pad_uint256(index)

              case eth_call(pm, token_id_data) do
                {:ok, token_id_hex} ->
                  token_id = decode_hex(token_id_hex)
                  positions_selector = encode_function_selector("positions", ["uint256"])
                  positions_data = positions_selector <> pad_uint256(token_id)

                  case eth_call(pm, positions_data) do
                    {:ok, result_hex} ->
                      pos = decode_positions_result(result_hex)
                      Map.put(pos, :token_id, token_id)
                    _ ->
                      nil
                  end
                _ ->
                  nil
              end
            end)
            |> Enum.filter(&(&1 != nil))

          {:ok, positions}
        else
          {:ok, []}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Decodes the 12-field tuple returned by the positions() call on NonfungiblePositionManager.
  """
  def decode_positions_result(hex_result) do
    hex = String.replace(hex_result, "0x", "")

    # Each field is 32 bytes (64 hex characters)
    chunks = for i <- 0..11, do: String.slice(hex, i * 64, 64)

    [
      nonce_hex,
      operator_hex,
      token0_hex,
      token1_hex,
      fee_hex,
      tick_lower_hex,
      tick_upper_hex,
      liquidity_hex,
      fee_growth_inside0_hex,
      fee_growth_inside1_hex,
      tokens_owed0_hex,
      tokens_owed1_hex
    ] = chunks

    %{
      nonce: decode_hex(nonce_hex),
      operator: decode_address(operator_hex),
      token0: decode_address(token0_hex),
      token1: decode_address(token1_hex),
      fee: decode_hex(fee_hex),
      tick_lower: decode_signed_int(tick_lower_hex, 256),
      tick_upper: decode_signed_int(tick_upper_hex, 256),
      liquidity: decode_hex(liquidity_hex),
      fee_growth_inside0_last_x128: decode_hex(fee_growth_inside0_hex),
      fee_growth_inside1_last_x128: decode_hex(fee_growth_inside1_hex),
      tokens_owed0: decode_hex(tokens_owed0_hex),
      tokens_owed1: decode_hex(tokens_owed1_hex)
    }
  end

  @doc """
  Gets a quote for a swap using the Quoter contract.
  """
  @spec get_swap_quote(String.t(), String.t(), integer(), integer(), integer()) :: {:ok, integer()} | {:error, term()}
  def get_swap_quote(token_in, token_out, fee, amount_in, sqrt_price_limit_x96 \\ 0) do
    quoter = contract_address(:quoter)
    selector = encode_function_selector("quoteExactInputSingle", ["address", "address", "uint24", "uint256", "uint160"])
    data = selector <> pad_address(token_in) <> pad_address(token_out) <> pad_uint24(fee) <> pad_uint256(amount_in) <> pad_uint256(sqrt_price_limit_x96)

    case eth_call(quoter, data) do
      {:ok, result_hex} ->
        {:ok, decode_hex(result_hex)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Encodes swap parameters into SwapRouter exactInputSingle calldata.
  """
  def encode_exact_input_single(params) do
    selector = encode_function_selector("exactInputSingle", ["(address,address,uint24,address,uint256,uint256,uint256,uint160)"])
    
    token_in = pad_address(params.token_in)
    token_out = pad_address(params.token_out)
    fee = pad_uint24(params.fee)
    recipient = pad_address(params.recipient)
    deadline = pad_uint256(params.deadline)
    amount_in = pad_uint256(params.amount_in)
    amount_out_minimum = pad_uint256(params.amount_out_minimum)
    sqrt_price_limit_x96 = pad_uint256(params.sqrt_price_limit_x96 || 0)

    selector <> token_in <> token_out <> fee <> recipient <> deadline <> amount_in <> amount_out_minimum <> sqrt_price_limit_x96
  end

  @doc """
  Encodes swap parameters into SwapRouter exactOutputSingle calldata.
  """
  def encode_exact_output_single(params) do
    selector = encode_function_selector("exactOutputSingle", ["(address,address,uint24,address,uint256,uint256,uint256,uint160)"])

    token_in = pad_address(params.token_in)
    token_out = pad_address(params.token_out)
    fee = pad_uint24(params.fee)
    recipient = pad_address(params.recipient)
    deadline = pad_uint256(params.deadline)
    amount_out = pad_uint256(params.amount_out)
    amount_in_maximum = pad_uint256(params.amount_in_maximum)
    sqrt_price_limit_x96 = pad_uint256(params.sqrt_price_limit_x96 || 0)

    selector <> token_in <> token_out <> fee <> recipient <> deadline <> amount_out <> amount_in_maximum <> sqrt_price_limit_x96
  end

  @doc """
  Encodes liquidity mint parameters into NonfungiblePositionManager mint calldata.
  """
  def encode_mint(params) do
    selector = encode_function_selector("mint", ["(address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256)"])

    token0 = pad_address(params.token0)
    token1 = pad_address(params.token1)
    fee = pad_uint24(params.fee)
    tick_lower = pad_uint256(params.tick_lower)
    tick_upper = pad_uint256(params.tick_upper)
    amount0_desired = pad_uint256(params.amount0_desired)
    amount1_desired = pad_uint256(params.amount1_desired)
    amount0_min = pad_uint256(params.amount0_min)
    amount1_min = pad_uint256(params.amount1_min)
    recipient = pad_address(params.recipient)
    deadline = pad_uint256(params.deadline)

    selector <> token0 <> token1 <> fee <> tick_lower <> tick_upper <> amount0_desired <> amount1_desired <> amount0_min <> amount1_min <> recipient <> deadline
  end

  @doc """
  Encodes decreaseLiquidity parameters into NonfungiblePositionManager decreaseLiquidity calldata.
  """
  def encode_decrease_liquidity(params) do
    selector = encode_function_selector("decreaseLiquidity", ["(uint256,uint128,uint256,uint256,uint256)"])

    token_id = pad_uint256(params.token_id)
    liquidity = pad_uint256(params.liquidity)
    amount0_min = pad_uint256(params.amount0_min)
    amount1_min = pad_uint256(params.amount1_min)
    deadline = pad_uint256(params.deadline)

    selector <> token_id <> liquidity <> amount0_min <> amount1_min <> deadline
  end

  @doc """
  Encodes collect parameters into NonfungiblePositionManager collect calldata.
  """
  def encode_collect(params) do
    selector = encode_function_selector("collect", ["(uint256,address,uint128,uint128)"])

    token_id = pad_uint256(params.token_id)
    recipient = pad_address(params.recipient)
    amount0_max = pad_uint256(params.amount0_max)
    amount1_max = pad_uint256(params.amount1_max)

    selector <> token_id <> recipient <> amount0_max <> amount1_max
  end

  # ─── Private Helpers ────────────────────────────────────────────────────

  defp alchemy_network_slug("mainnet"), do: "eth-mainnet"
  defp alchemy_network_slug("goerli"), do: "eth-goerli"
  defp alchemy_network_slug("sepolia"), do: "eth-sepolia"
  defp alchemy_network_slug("arbitrum"), do: "arb-mainnet"
  defp alchemy_network_slug("optimism"), do: "opt-mainnet"
  defp alchemy_network_slug("polygon"), do: "polygon-mainnet"
  defp alchemy_network_slug("base"), do: "base-mainnet"
  defp alchemy_network_slug(_), do: "eth-mainnet"

  @doc false
  def decode_signed_int("0x" <> hex, bit_size) do
    value = decode_hex("0x" <> hex)
    max_positive = :math.pow(2, bit_size - 1) |> round()

    if value >= max_positive do
      value - round(:math.pow(2, bit_size))
    else
      value
    end
  end

  def decode_signed_int(hex, bit_size) when is_binary(hex) do
    decode_signed_int("0x" <> hex, bit_size)
  end
end
