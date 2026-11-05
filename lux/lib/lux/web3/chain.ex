defmodule Lux.Web3.Chain do
  @moduledoc """
  Registry of the EVM chains supported by the Lux web3 infrastructure.

  A chain is described by a plain map with the following keys:

    * `:chain_id` - numeric EVM chain id
    * `:name` - canonical, lowercase chain name
    * `:native_currency` - symbol of the native gas currency
    * `:explorer` - block explorer base url

  ## Examples

      iex> {:ok, chain} = Lux.Web3.Chain.get(1)
      iex> chain.name
      "ethereum"

      iex> Lux.Web3.Chain.supported?(137)
      true

      iex> Lux.Web3.Chain.get(424_242)
      {:error, :unsupported_chain}
  """

  @type t :: %{
          chain_id: non_neg_integer(),
          name: String.t(),
          native_currency: String.t(),
          explorer: String.t()
        }

  @chains %{
    1 => %{
      chain_id: 1,
      name: "ethereum",
      native_currency: "ETH",
      explorer: "https://etherscan.io"
    },
    10 => %{
      chain_id: 10,
      name: "optimism",
      native_currency: "ETH",
      explorer: "https://optimistic.etherscan.io"
    },
    56 => %{
      chain_id: 56,
      name: "bnb-smart-chain",
      native_currency: "BNB",
      explorer: "https://bscscan.com"
    },
    137 => %{
      chain_id: 137,
      name: "polygon",
      native_currency: "POL",
      explorer: "https://polygonscan.com"
    },
    8453 => %{
      chain_id: 8453,
      name: "base",
      native_currency: "ETH",
      explorer: "https://basescan.org"
    },
    42_161 => %{
      chain_id: 42_161,
      name: "arbitrum",
      native_currency: "ETH",
      explorer: "https://arbiscan.io"
    },
    43_114 => %{
      chain_id: 43_114,
      name: "avalanche",
      native_currency: "AVAX",
      explorer: "https://snowtrace.io"
    }
  }

  @doc """
  Returns every supported chain sorted by ascending `chain_id`.
  """
  @spec all() :: [t()]
  def all, do: @chains |> Map.values() |> Enum.sort_by(& &1.chain_id)

  @doc """
  Returns the sorted list of supported numeric chain ids.
  """
  @spec supported_chain_ids() :: [non_neg_integer()]
  def supported_chain_ids, do: @chains |> Map.keys() |> Enum.sort()

  @doc """
  Returns `true` when the given chain id is supported.
  """
  @spec supported?(term()) :: boolean()
  def supported?(chain_id) when is_integer(chain_id), do: Map.has_key?(@chains, chain_id)
  def supported?(_chain_id), do: false

  @doc """
  Fetches a chain by numeric id (integers or numeric strings are accepted).
  """
  @spec get(term()) :: {:ok, t()} | {:error, :unsupported_chain | :invalid_chain_id}
  def get(chain_id) do
    case normalize_chain_id(chain_id) do
      {:ok, id} ->
        case Map.fetch(@chains, id) do
          {:ok, chain} -> {:ok, chain}
          :error -> {:error, :unsupported_chain}
        end

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Same as `get/1` but raises when the chain is not supported.
  """
  @spec get!(term()) :: t()
  def get!(chain_id) do
    case get(chain_id) do
      {:ok, chain} ->
        chain

      {:error, reason} ->
        raise ArgumentError, "unsupported chain #{inspect(chain_id)} (#{inspect(reason)})"
    end
  end

  @doc """
  Finds a chain by its canonical name (case insensitive).
  """
  @spec find_by_name(term()) :: {:ok, t()} | {:error, :unknown_chain}
  def find_by_name(name) when is_binary(name) do
    normalized = name |> String.trim() |> String.downcase()

    case Enum.find(all(), &(&1.name == normalized)) do
      nil -> {:error, :unknown_chain}
      chain -> {:ok, chain}
    end
  end

  def find_by_name(_name), do: {:error, :unknown_chain}

  @doc """
  Returns the chain name for a chain id.
  """
  @spec name(term()) :: {:ok, String.t()} | {:error, :unsupported_chain | :invalid_chain_id}
  def name(chain_id) do
    case get(chain_id) do
      {:ok, chain} -> {:ok, chain.name}
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Returns the native currency symbol for a chain id.
  """
  @spec native_currency(term()) ::
          {:ok, String.t()} | {:error, :unsupported_chain | :invalid_chain_id}
  def native_currency(chain_id) do
    case get(chain_id) do
      {:ok, chain} -> {:ok, chain.native_currency}
      {:error, _reason} = error -> error
    end
  end

  defp normalize_chain_id(chain_id) when is_integer(chain_id) and chain_id >= 0,
    do: {:ok, chain_id}

  defp normalize_chain_id(chain_id) when is_binary(chain_id) do
    case Integer.parse(String.trim(chain_id)) do
      {id, ""} when id >= 0 -> {:ok, id}
      _ -> {:error, :invalid_chain_id}
    end
  end

  defp normalize_chain_id(_chain_id), do: {:error, :invalid_chain_id}
end
