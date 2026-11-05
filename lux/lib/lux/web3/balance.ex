defmodule Lux.Web3.Balance do
  @moduledoc """
  Balance tracking for wallets across multiple EVM chains.

  Balances are stored per `(address, chain_id)` pair and can be aggregated
  across chains for a single address. The tracker can also refresh balances
  from an external provider implementing the `Lux.Web3.Balance.Provider`
  behaviour.

  ## Examples

      iex> {:ok, tracker} = Lux.Web3.Balance.start_link()
      iex> {:ok, _balance} = Lux.Web3.Balance.put(tracker, "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1", 1, 1_500_000_000_000_000_000)
      iex> {:ok, total} = Lux.Web3.Balance.total(tracker, "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1")
      iex> total
      1500000000000000000
      iex> Lux.Web3.Balance.format(total)
      "1.5 ETH"
  """

  use GenServer

  alias Ethers.Utils
  alias Lux.Web3.Chain

  @type balance :: %{address: String.t(), chain_id: non_neg_integer(), wei: non_neg_integer()}

  @doc """
  Starts a balance tracker.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    case Keyword.get(opts, :name) do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc """
  Child spec for supervision trees.
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  @doc """
  Stores a balance for an address on a chain.
  """
  @spec put(GenServer.server(), term(), term(), term()) :: {:ok, balance()} | {:error, atom()}
  def put(server, address, chain_id, wei) do
    GenServer.call(server, {:put, address, chain_id, wei})
  end

  @doc """
  Fetches a stored balance.
  """
  @spec get(GenServer.server(), term(), term()) :: {:ok, balance()} | {:error, atom()}
  def get(server, address, chain_id) do
    GenServer.call(server, {:get, address, chain_id})
  end

  @doc """
  Lists every stored balance for an address.
  """
  @spec list(GenServer.server(), term()) :: {:ok, [balance()]} | {:error, atom()}
  def list(server, address), do: GenServer.call(server, {:list, address})

  @doc """
  Sums every stored balance for an address across chains.
  """
  @spec total(GenServer.server(), term()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def total(server, address), do: GenServer.call(server, {:total, address})

  @doc """
  Refreshes balances for an address across the given chains using a provider.
  """
  @spec refresh(GenServer.server(), term(), [non_neg_integer()], keyword()) ::
          {:ok, [balance()]} | {:error, atom()}
  def refresh(server, address, chain_ids, opts \\ []) do
    GenServer.call(server, {:refresh, address, chain_ids, opts}, 30_000)
  end

  @doc """
  Formats a wei amount as a human readable string.
  """
  @spec format(non_neg_integer(), String.t(), non_neg_integer()) :: String.t()
  def format(wei, symbol \\ "ETH", decimals \\ 18)

  def format(wei, symbol, decimals)
      when is_integer(wei) and wei >= 0 and is_binary(symbol) and is_integer(decimals) and
             decimals >= 0 do
    factor = Integer.pow(10, decimals)
    whole = div(wei, factor)
    fraction = rem(wei, factor)

    if fraction == 0 do
      "#{whole} #{symbol}"
    else
      fraction_string =
        fraction
        |> Integer.to_string()
        |> String.pad_leading(decimals, "0")
        |> String.trim_trailing("0")

      "#{whole}.#{fraction_string} #{symbol}"
    end
  end

  @doc """
  Converts a whole unit amount into wei.
  """
  @spec to_wei(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def to_wei(amount, decimals \\ 18) when is_integer(amount) and amount >= 0 do
    amount * Integer.pow(10, decimals)
  end

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_call({:put, address, chain_id, wei}, _from, state) do
    with {:ok, address} <- normalize_address(address),
         {:ok, chain} <- normalize_chain(chain_id),
         {:ok, wei} <- normalize_wei(wei) do
      balance = %{address: address, chain_id: chain.chain_id, wei: wei}
      {:reply, {:ok, balance}, Map.put(state, {address, chain.chain_id}, wei)}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get, address, chain_id}, _from, state) do
    with {:ok, address} <- normalize_address(address),
         {:ok, chain} <- normalize_chain(chain_id) do
      case Map.fetch(state, {address, chain.chain_id}) do
        {:ok, wei} ->
          {:reply, {:ok, %{address: address, chain_id: chain.chain_id, wei: wei}}, state}

        :error ->
          {:reply, {:error, :not_found}, state}
      end
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:list, address}, _from, state) do
    case normalize_address(address) do
      {:ok, address} ->
        balances =
          state
          |> Enum.filter(fn {{stored_address, _chain_id}, _wei} -> stored_address == address end)
          |> Enum.map(fn {{stored_address, chain_id}, wei} ->
            %{address: stored_address, chain_id: chain_id, wei: wei}
          end)
          |> Enum.sort_by(& &1.chain_id)

        {:reply, {:ok, balances}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:total, address}, _from, state) do
    case normalize_address(address) do
      {:ok, address} ->
        total =
          state
          |> Enum.filter(fn {{stored_address, _chain_id}, _wei} -> stored_address == address end)
          |> Enum.reduce(0, fn {_key, wei}, acc -> acc + wei end)

        {:reply, {:ok, total}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:refresh, address, chain_ids, opts}, _from, state) do
    with {:ok, address} <- normalize_address(address),
         {:ok, chain_ids} <- normalize_chain_ids(chain_ids),
         {:ok, provider} <- normalize_provider(Keyword.get(opts, :provider)) do
      {balances, new_state} =
        Enum.reduce(chain_ids, {[], state}, fn chain_id, {acc, current_state} ->
          case provider.balance(address, chain_id, opts) do
            {:ok, wei} when is_integer(wei) and wei >= 0 ->
              balance = %{address: address, chain_id: chain_id, wei: wei}
              {[balance | acc], Map.put(current_state, {address, chain_id}, wei)}

            _error ->
              {acc, current_state}
          end
        end)

      {:reply, {:ok, Enum.reverse(balances)}, new_state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp normalize_address(address) when is_binary(address) do
    case Utils.decode_address(String.trim(address)) do
      {:ok, decoded} -> {:ok, Utils.encode_address!(decoded)}
      {:error, _reason} -> {:error, :invalid_address}
    end
  end

  defp normalize_address(_address), do: {:error, :invalid_address}

  defp normalize_chain(chain_id) do
    case Chain.get(chain_id) do
      {:ok, chain} -> {:ok, chain}
      {:error, _reason} = error -> error
    end
  end

  defp normalize_chain_ids(chain_ids) when is_list(chain_ids), do: {:ok, chain_ids}
  defp normalize_chain_ids(_chain_ids), do: {:error, :invalid_chain_ids}

  defp normalize_wei(wei) when is_integer(wei) and wei >= 0, do: {:ok, wei}
  defp normalize_wei(_wei), do: {:error, :invalid_amount}

  defp normalize_provider(nil), do: {:error, :missing_provider}
  defp normalize_provider(provider) when is_atom(provider), do: {:ok, provider}
  defp normalize_provider(_provider), do: {:error, :invalid_provider}
end
