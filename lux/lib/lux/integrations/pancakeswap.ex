defmodule Lux.Integrations.PancakeSwap do
  @moduledoc """
  Chain registry, contract addresses and small helpers for the PancakeSwap integration.

  The integration is read-only on chain: reads go through JSON-RPC `eth_call`
  (see `Lux.Integrations.PancakeSwap.Client`) and every write operation returns
  *unsigned* transaction requests that the caller signs and broadcasts with their own
  wallet. Lux never handles private keys for PancakeSwap.

  ## Supported chains

  `chain/1` accepts a chain name (`"bsc"`, `"ethereum"`, `"arbitrum"`, `"base"`) or its
  numeric chain id. Farming through MasterChef V2 (`:masterchef_v2`) is only available on
  BNB Smart Chain. On other chains pass a `:masterchef` address override to the prisms.

  Every contract address and the RPC URL can be overridden per call (`:rpc_url`,
  `:masterchef`, `:router`, `:factory`), so you can point the prisms at a private RPC node
  or a fork.
  """

  @type chain :: %{
          required(:id) => pos_integer(),
          required(:name) => String.t(),
          required(:rpc_url) => String.t(),
          optional(atom()) => term()
        }

  @chains %{
    "bsc" => %{
      id: 56,
      name: "bsc",
      rpc_url: "https://bsc-dataseed.binance.org",
      native_symbol: "BNB",
      blocks_per_year: 10_512_000,
      cake: "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
      wrapped_native: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
      masterchef_v2: "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652",
      router_v2: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
      factory_v2: "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"
    },
    "ethereum" => %{
      id: 1,
      name: "ethereum",
      rpc_url: "https://ethereum-rpc.publicnode.com",
      native_symbol: "ETH",
      blocks_per_year: 2_628_000,
      cake: "0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898",
      wrapped_native: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      masterchef_v2: nil,
      router_v2: "0xEfF92A263d31888d860bD50809A8D171709b7b1c",
      factory_v2: "0x1097053Fd2ea711dad45caCcc45EfF7548fCB362"
    },
    "arbitrum" => %{
      id: 42_161,
      name: "arbitrum",
      rpc_url: "https://arb1.arbitrum.io/rpc",
      native_symbol: "ETH",
      blocks_per_year: 126_144_000,
      cake: "0x1b896893dfc86bb67Cf57767298b9073D2c1bA2c",
      wrapped_native: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
      masterchef_v2: nil,
      router_v2: "0x8cFe327CEc66d1C090Dd72bd0FF11d690C33a2Eb",
      factory_v2: "0x02a84c1b3BBD7401a5f7fa98a384EBC70bB5749E"
    },
    "base" => %{
      id: 8453,
      name: "base",
      rpc_url: "https://mainnet.base.org",
      native_symbol: "ETH",
      blocks_per_year: 15_768_000,
      cake: "0x3055913c90Fcc1A6CE9a358911721eEb942013A1",
      wrapped_native: "0x4200000000000000000000000000000000000006",
      masterchef_v2: nil,
      router_v2: "0x8cFe327CEc66d1C090Dd72bd0FF11d690C33a2Eb",
      factory_v2: "0x02a84c1b3BBD7401a5f7fa98a384EBC70bB5749E"
    }
  }

  @doc """
  Returns the full chain registry keyed by chain name.
  """
  @spec chains() :: %{String.t() => chain()}
  def chains, do: @chains

  @doc """
  Returns the sorted list of supported chain names.
  """
  @spec supported_chains() :: [String.t()]
  def supported_chains, do: @chains |> Map.keys() |> Enum.sort()

  @doc """
  Looks up a chain by name (case-insensitive), atom, numeric id or numeric string.

  ## Examples

      iex> {:ok, chain} = Lux.Integrations.PancakeSwap.chain("BSC")
      iex> chain.id
      56

      iex> Lux.Integrations.PancakeSwap.chain(8453) |> elem(1) |> Map.get(:name)
      "base"

      iex> Lux.Integrations.PancakeSwap.chain("solana")
      {:error, :unsupported_chain}
  """
  @spec chain(term()) :: {:ok, chain()} | {:error, :unsupported_chain}
  def chain(id) when is_integer(id) do
    case Enum.find(Map.values(@chains), &(&1.id == id)) do
      nil -> {:error, :unsupported_chain}
      chain -> {:ok, chain}
    end
  end

  def chain(name) when is_binary(name) do
    normalized = name |> String.trim() |> String.downcase()

    case Map.fetch(@chains, normalized) do
      {:ok, chain} ->
        {:ok, chain}

      :error ->
        case Integer.parse(normalized) do
          {id, ""} -> chain(id)
          _ -> {:error, :unsupported_chain}
        end
    end
  end

  def chain(name) when is_atom(name) and not is_nil(name), do: chain(Atom.to_string(name))
  def chain(_), do: {:error, :unsupported_chain}

  @doc """
  Same as `chain/1` but returns a human readable error string.
  """
  @spec fetch_chain(term()) :: {:ok, chain()} | {:error, String.t()}
  def fetch_chain(id) do
    case chain(id) do
      {:ok, chain} ->
        {:ok, chain}

      {:error, :unsupported_chain} ->
        {:error,
         "Unsupported chain: #{inspect(id)}. Supported chains: #{Enum.join(supported_chains(), ", ")}"}
    end
  end

  @doc """
  Resolves a contract address for the chain, preferring `override` when given.

  `key` is one of `:cake`, `:wrapped_native`, `:masterchef_v2`, `:router_v2`, `:factory_v2`.
  """
  @spec address(chain(), atom(), String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def address(chain, key, override \\ nil)

  def address(_chain, _key, override) when is_binary(override) do
    if valid_address?(override) do
      {:ok, override}
    else
      {:error, "Invalid address: #{override}"}
    end
  end

  def address(chain, key, nil) do
    case Map.get(chain, key) do
      nil -> {:error, "#{key} contract is not configured for #{chain.name}"}
      address -> {:ok, address}
    end
  end

  def address(_chain, key, override), do: {:error, "Invalid #{key} address: #{inspect(override)}"}

  @doc """
  Returns true for a `0x`-prefixed 20 byte hex string.
  """
  @spec valid_address?(term()) :: boolean()
  def valid_address?(address) when is_binary(address),
    do: Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address)

  def valid_address?(_), do: false

  @doc """
  Parses a non-negative integer amount given as an integer or a decimal string.
  """
  @spec parse_amount(term()) :: {:ok, non_neg_integer()} | :error
  def parse_amount(amount) when is_integer(amount) and amount >= 0, do: {:ok, amount}

  def parse_amount(amount) when is_binary(amount) do
    if Regex.match?(~r/^\d+$/, amount), do: {:ok, String.to_integer(amount)}, else: :error
  end

  def parse_amount(_), do: :error

  @doc """
  Parses a strictly positive integer amount.
  """
  @spec parse_positive_amount(term()) :: {:ok, pos_integer()} | :error
  def parse_positive_amount(amount) do
    case parse_amount(amount) do
      {:ok, value} when value > 0 -> {:ok, value}
      _ -> :error
    end
  end

  @doc """
  Reads `key` from a map that may use atom or string keys.
  """
  @spec field(map(), atom(), term()) :: term()
  def field(map, key, default \\ nil) when is_map(map) and is_atom(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key), default)
    end
  end

  @doc """
  Builds the options passed to the RPC client from prism input.
  """
  @spec rpc_opts(map()) :: keyword()
  def rpc_opts(input), do: [rpc_url: field(input, :rpc_url)]

  @doc """
  Returns the transaction deadline (unix seconds) for prism input.

  Uses `:deadline` when given, otherwise `:now` (default: the current time) plus 20 minutes.
  """
  @spec deadline(map()) :: pos_integer()
  def deadline(input) do
    case field(input, :deadline) do
      deadline when is_integer(deadline) and deadline > 0 ->
        deadline

      _ ->
        (field(input, :now) || System.os_time(:second)) + 1_200
    end
  end

  @doc """
  Converts an error reason from the client into a string.
  """
  @spec format_error(term()) :: String.t()
  def format_error(reason) when is_binary(reason), do: reason
  def format_error({:rpc_error, code, message}), do: "RPC error #{code}: #{message}"
  def format_error({:http_error, status, body}), do: "HTTP #{status}: #{inspect(body)}"
  def format_error(%{__exception__: true} = exception), do: Exception.message(exception)
  def format_error(reason), do: inspect(reason)

  @doc """
  Applies a slippage tolerance (in basis points) to an amount, rounding down.

  ## Examples

      iex> Lux.Integrations.PancakeSwap.apply_slippage(10_000, 50)
      9_950
  """
  @spec apply_slippage(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def apply_slippage(amount, slippage_bps), do: div(amount * (10_000 - slippage_bps), 10_000)

  @doc """
  Validates a slippage tolerance in basis points (0 to 10_000).
  """
  @spec parse_slippage(term()) :: {:ok, 0..10_000} | {:error, String.t()}
  def parse_slippage(nil), do: {:ok, 50}
  def parse_slippage(bps) when is_integer(bps) and bps >= 0 and bps <= 10_000, do: {:ok, bps}
  def parse_slippage(_), do: {:error, "slippage_bps must be an integer between 0 and 10000"}
end
