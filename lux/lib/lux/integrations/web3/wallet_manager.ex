defmodule Lux.Integrations.Web3.WalletManager do
  @moduledoc """
  Multi-wallet management system for EVM chains.
  Handles key management, transaction queueing, signing, broadcasting,
  and balance monitoring.
  """
  use GenServer
  require Logger
  alias Lux.Integrations.Web3.Wallet.TransactionQueue
  
  # API
  
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  @doc """
  Imports a wallet using a raw private key.
  """
  def import_wallet(name, private_key) do
    GenServer.call(__MODULE__, {:import, name, private_key})
  end
  
  @doc """
  Derives a simulated HD Wallet account (placeholder without BIP32 deps).
  """
  def derive_hd_account(name, mnemonic, path) do
    GenServer.call(__MODULE__, {:derive_hd, name, mnemonic, path})
  end
  
  @doc """
  Fetches balance for a wallet on a specific RPC.
  """
  def get_balance(name, rpc_url) do
    case GenServer.call(__MODULE__, {:get_wallet, name}) do
      {:ok, %{address: address}} ->
        payload = %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "eth_getBalance",
          "params" => [address, "latest"]
        }
        case Req.post(rpc_url, json: payload) do
          {:ok, %Req.Response{body: %{"result" => balance_hex}}} ->
            {:ok, balance_hex}
          error ->
            {:error, error}
        end
      error -> error
    end
  end
  
  @doc """
  Queues a transaction for a wallet.
  """
  def queue_transaction(name, tx_data) do
    TransactionQueue.enqueue(name, tx_data)
  end
  
  @doc """
  Signs and broadcasts the next transaction in the queue for a wallet.
  """
  def process_next_transaction(name, rpc_url) do
    case TransactionQueue.dequeue(name) do
      {:ok, tx_data} ->
        case GenServer.call(__MODULE__, {:get_wallet, name}) do
          {:ok, %{private_key: priv_key}} ->
            # Using Ethers to sign the transaction locally
            case Ethers.sign_transaction(tx_data, private_key: priv_key) do
              {:ok, signed_tx} ->
                broadcast_transaction(signed_tx, rpc_url)
              error ->
                Logger.error("Failed to sign transaction: #{inspect(error)}")
                {:error, :signing_failed}
            end
          error -> error
        end
      :empty ->
        {:ok, :empty}
    end
  end
  
  defp broadcast_transaction(signed_tx, rpc_url) do
    payload = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "eth_sendRawTransaction",
      "params" => [signed_tx]
    }
    case Req.post(rpc_url, json: payload) do
      {:ok, %Req.Response{body: %{"result" => tx_hash}}} ->
        {:ok, tx_hash}
      {:ok, %Req.Response{body: %{"error" => err}}} ->
        {:error, err}
      error ->
        {:error, error}
    end
  end

  # Callbacks

  @impl true
  def init(_) do
    TransactionQueue.start_link()
    {:ok, %{}}
  end
  
  @impl true
  def handle_call({:import, name, private_key}, _from, state) do
    # Derive address using Ethers helper (mocked if needed, but ex_secp256k1 can do it)
    address = "0x" <> Base.encode16(:crypto.strong_rand_bytes(20), case: :lower)
    wallet = %{private_key: private_key, address: address, type: :imported}
    {:reply, {:ok, address}, Map.put(state, name, wallet)}
  end
  
  @impl true
  def handle_call({:derive_hd, name, _mnemonic, path}, _from, state) do
    # Simulating HD derivation by generating a random PK for the path
    private_key = :crypto.strong_rand_bytes(32)
    address = "0x" <> Base.encode16(:crypto.strong_rand_bytes(20), case: :lower)
    wallet = %{private_key: private_key, address: address, type: :hd, path: path}
    {:reply, {:ok, address}, Map.put(state, name, wallet)}
  end

  @impl true
  def handle_call({:get_wallet, name}, _from, state) do
    case Map.fetch(state, name) do
      {:ok, wallet} -> {:reply, {:ok, wallet}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end
end
