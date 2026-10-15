defmodule Lux.Web3.Chains do
  @moduledoc """
  Multi-chain EVM network registry and JSON-RPC client helper.

  Provides built-in chain configurations for major EVM networks (Ethereum,
  Arbitrum, Optimism, Base, Polygon, BSC, Avalanche, and Sepolia), custom chain
  registration, and a testable JSON-RPC transport backed by `Req`.
  """

  @table :lux_web3_chains

  defmodule ChainConfig do
    @moduledoc """
    Configuration and metadata for an EVM-compatible blockchain network.
    """

    @type t :: %__MODULE__{
            id: atom(),
            chain_id: pos_integer(),
            name: String.t(),
            native_symbol: String.t(),
            decimals: pos_integer(),
            rpc_url: String.t(),
            explorer_url: String.t() | nil,
            eip1559_supported: boolean()
          }

    defstruct id: :ethereum,
              chain_id: 1,
              name: "Ethereum Mainnet",
              native_symbol: "ETH",
              decimals: 18,
              rpc_url: "https://eth.llamarpc.com",
              explorer_url: "https://etherscan.io",
              eip1559_supported: true
  end

  @doc """
  Ensures the chain registry ETS table is initialized with built-in EVM chains.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
          seed_defaults()
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end

  @doc """
  Resets the chain registry to built-in defaults.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@table)
    seed_defaults()
  end

  @doc """
  Registers or updates an EVM chain configuration.
  """
  @spec register_chain(ChainConfig.t() | map()) :: {:ok, ChainConfig.t()}
  def register_chain(%ChainConfig{} = chain) do
    ensure_started()
    :ets.insert(@table, {chain.id, chain})
    {:ok, chain}
  end

  def register_chain(attrs) when is_map(attrs) do
    chain = struct(ChainConfig, attrs)
    register_chain(chain)
  end

  @doc """
  Looks up a chain configuration by atom identifier (e.g. `:ethereum`, `:polygon`)
  or numeric `chain_id` (e.g. `1`, `137`).
  """
  @spec get_chain(atom() | pos_integer()) :: {:ok, ChainConfig.t()} | {:error, :unknown_chain}
  def get_chain(id) when is_atom(id) do
    ensure_started()

    case :ets.lookup(@table, id) do
      [{^id, chain}] -> {:ok, chain}
      [] -> {:error, :unknown_chain}
    end
  end

  def get_chain(chain_id) when is_integer(chain_id) do
    ensure_started()

    @table
    |> :ets.tab2list()
    |> Enum.find_value({:error, :unknown_chain}, fn {_id, chain} ->
      if chain.chain_id == chain_id, do: {:ok, chain}
    end)
  end

  @doc """
  Lists all registered EVM chains sorted by `chain_id`.
  """
  @spec list_chains() :: [ChainConfig.t()]
  def list_chains do
    ensure_started()

    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, chain} -> chain end)
    |> Enum.sort_by(& &1.chain_id)
  end

  @doc """
  Executes a JSON-RPC request against the specified chain.
  """
  @spec rpc_call(atom() | pos_integer(), String.t(), list(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def rpc_call(chain_ref, method, params \\ [], opts \\ []) do
    with {:ok, chain} <- get_chain(chain_ref) do
      rpc_url = Keyword.get(opts, :rpc_url, chain.rpc_url)
      req_id = Keyword.get(opts, :id, System.unique_integer([:positive]))

      payload = %{
        "jsonrpc" => "2.0",
        "id" => req_id,
        "method" => method,
        "params" => params
      }

      req_opts =
        [
          url: rpc_url,
          json: payload,
          headers: [{"Content-Type", "application/json"}]
        ]
        |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
        |> Keyword.merge(Keyword.get(opts, :req_options, []))

      case Req.post(Req.new(req_opts)) do
        {:ok, %{status: 200, body: %{"result" => result}}} ->
          {:ok, result}

        {:ok, %{status: 200, body: %{"error" => error}}} ->
          {:error, {:rpc_error, error}}

        {:ok, %{status: status, body: body}} ->
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Parses a hexadecimal quantity string (e.g. `"0xde0b6b3a7640000"`) into an integer.
  """
  @spec hex_to_integer(String.t() | integer()) ::
          {:ok, non_neg_integer()} | {:error, :invalid_hex}
  def hex_to_integer(value) when is_integer(value) and value >= 0, do: {:ok, value}
  def hex_to_integer("0x0"), do: {:ok, 0}
  def hex_to_integer("0x"), do: {:ok, 0}

  def hex_to_integer("0x" <> hex) do
    case Integer.parse(hex, 16) do
      {int, ""} when int >= 0 -> {:ok, int}
      _ -> {:error, :invalid_hex}
    end
  end

  def hex_to_integer(_), do: {:error, :invalid_hex}

  @doc """
  Formats a non-negative integer as a `0x`-prefixed hexadecimal quantity string.
  """
  @spec integer_to_hex(non_neg_integer()) :: String.t()
  def integer_to_hex(0), do: "0x0"

  def integer_to_hex(value) when is_integer(value) and value > 0 do
    "0x" <> String.downcase(Integer.to_string(value, 16))
  end

  defp seed_defaults do
    Enum.each(default_chains(), fn chain ->
      :ets.insert(@table, {chain.id, chain})
    end)

    :ok
  end

  defp default_chains do
    [
      %ChainConfig{
        id: :ethereum,
        chain_id: 1,
        name: "Ethereum Mainnet",
        native_symbol: "ETH",
        decimals: 18,
        rpc_url: "https://eth.llamarpc.com",
        explorer_url: "https://etherscan.io",
        eip1559_supported: true
      },
      %ChainConfig{
        id: :optimism,
        chain_id: 10,
        name: "Optimism",
        native_symbol: "ETH",
        decimals: 18,
        rpc_url: "https://mainnet.optimism.io",
        explorer_url: "https://optimistic.etherscan.io",
        eip1559_supported: true
      },
      %ChainConfig{
        id: :bsc,
        chain_id: 56,
        name: "BNB Smart Chain",
        native_symbol: "BNB",
        decimals: 18,
        rpc_url: "https://bsc-dataseed.binance.org",
        explorer_url: "https://bscscan.com",
        eip1559_supported: false
      },
      %ChainConfig{
        id: :polygon,
        chain_id: 137,
        name: "Polygon PoS",
        native_symbol: "POL",
        decimals: 18,
        rpc_url: "https://polygon-rpc.com",
        explorer_url: "https://polygonscan.com",
        eip1559_supported: true
      },
      %ChainConfig{
        id: :base,
        chain_id: 8453,
        name: "Base",
        native_symbol: "ETH",
        decimals: 18,
        rpc_url: "https://mainnet.base.org",
        explorer_url: "https://basescan.org",
        eip1559_supported: true
      },
      %ChainConfig{
        id: :arbitrum,
        chain_id: 42_161,
        name: "Arbitrum One",
        native_symbol: "ETH",
        decimals: 18,
        rpc_url: "https://arb1.arbitrum.io/rpc",
        explorer_url: "https://arbiscan.io",
        eip1559_supported: true
      },
      %ChainConfig{
        id: :avalanche,
        chain_id: 43_114,
        name: "Avalanche C-Chain",
        native_symbol: "AVAX",
        decimals: 18,
        rpc_url: "https://api.avax.network/ext/bc/C/rpc",
        explorer_url: "https://snowtrace.io",
        eip1559_supported: true
      },
      %ChainConfig{
        id: :sepolia,
        chain_id: 11_155_111,
        name: "Ethereum Sepolia",
        native_symbol: "ETH",
        decimals: 18,
        rpc_url: "https://rpc.sepolia.org",
        explorer_url: "https://sepolia.etherscan.io",
        eip1559_supported: true
      }
    ]
  end
end
