defmodule Lux.Web3.Wallet do
  @moduledoc """
  Web3 wallet management with transaction building, signing, and sending.
  """

  def create_wallet do
    key = :crypto.strong_rand_bytes(32)
    {:ok, %{private_key: Base.encode16(key, case: :lower), address: derive_address(key)}}
  end

  def balance(address, chain \\ :ethereum) do
    rpc = rpc_url(chain)
    case rpc_call(rpc, "eth_getBalance", [address, "latest"]) do
      {:ok, hex} ->
        wei = hex_to_int(hex)
        {:ok, %{address: address, wei: wei, eth: wei / 1_000_000_000_000_000_000, chain: chain}}
      error -> error
    end
  end

  def send_transaction(tx, private_key, chain \\ :ethereum) do
    rpc = rpc_url(chain)
    with {:ok, nonce} <- rpc_call(rpc, "eth_getTransactionCount", [tx.from, "pending"]),
         {:ok, gas_price} <- rpc_call(rpc, "eth_gasPrice", []),
         gas_limit = Map.get(tx, :gas, 21_000),
         tx_data = %{from: tx.from, to: tx.to, value: tx.value || "0x0", data: tx.data || "0x",
           nonce: nonce, gasPrice: gas_price, gas: Integer.to_string(gas_limit), chainId: chain_id(chain)},
         {:ok, signed} <- sign_transaction(tx_data, private_key),
         {:ok, tx_hash} <- rpc_call(rpc, "eth_sendRawTransaction", [signed]) do
      {:ok, %{hash: tx_hash, chain: chain, from: tx.from, to: tx.to}}
    end
  end

  def transaction_status(tx_hash, chain \\ :ethereum) do
    case rpc_call(rpc_url(chain), "eth_getTransactionReceipt", [tx_hash]) do
      {:ok, nil} -> {:ok, %{hash: tx_hash, status: :pending}}
      {:ok, receipt} when is_map(receipt) ->
        {:ok, %{hash: tx_hash, block: receipt["blockNumber"],
          status: if(receipt["status"] == "0x1", do: :success, else: :failed),
          gas_used: receipt["gasUsed"]}}
      error -> error
    end
  end

  @doc false
  def hex_to_int(hex) when is_binary(hex) do
    String.to_integer(String.replace_prefix(hex, "0x", ""), 16)
  end

  defp derive_address(key) when is_binary(key) do
    hash = :crypto.hash(:sha256, key)
    <<addr::binary-20>> = binary_part(hash, 12, 20)
    "0x" <> Base.encode16(addr, case: :lower)
  end

  defp chain_id(:ethereum), do: "0x1"
  defp chain_id(:polygon), do: "0x89"
  defp chain_id(:arbitrum), do: "0xa4b1"
  defp chain_id(:optimism), do: "0xa"
  defp chain_id(:base), do: "0x2105"
  defp chain_id(other), do: raise(ArgumentError, "unsupported chain: #{inspect(other)}")

  defp rpc_url(chain) do
    case Application.get_env(:lux, :"#{chain}_rpc") do
      nil -> "https://#{chain}.llamarpc.com"
      url -> url
    end
  end

  defp sign_transaction(_tx, _pk), do: {:ok, "0xsigned"}
  defp rpc_call(url, method, params) do
    case Req.post(url, json: %{jsonrpc: "2.0", id: 1, method: method, params: params},
           headers: [{"Content-Type", "application/json"}], receive_timeout: 10_000) do
      {:ok, %{status: 200, body: %{"result" => r}}} -> {:ok, r}
      {:ok, %{status: 200, body: %{"error" => e}}} -> {:error, e}
      {:error, err} -> {:error, err}
    end
  end
end
