defmodule Lux.Integrations.MultiChain.Polygon do
  @moduledoc "Polygon PoS chain adapter."
  use Lux.Integrations.MultiChain.ChainAdapter
  @chain :polygon; @chain_id "137"; @rpc_url "https://polygon-rpc.com"
  @native_currency "MATIC"; @symbol "MATIC"
  @impl true; def chain_name, do: "Polygon"
  @impl true; def chain_id, do: @chain_id
  @impl true; def native_currency, do: @native_currency
  @impl true; def symbol, do: @symbol
  @impl true
  def fetch_balance(address, block \\ "latest") do
    with {:ok, addr} <- validate_address(address) do
      case rpc(@rpc_url, json_rpc(:eth_getBalance, [addr, block_to_hex(block)])) do
        {:ok, %{"result" => result}} ->
          {:ok, %{address: addr, balance_wei: result, balance_native: wei_to_native(result), block: block, chain: @chain, currency: @native_currency}}
        {:error, reason} -> {:error, "Polygon balance fetch failed: #{reason}"}
      end
    end
  end
  @impl true
  def fetch_block_number do
    case rpc(@rpc_url, json_rpc(:eth_blockNumber, [])) do
      {:ok, %{"result" => block_hex}} ->
        {:ok, %{block_number: String.trim_leading(block_hex, "0x") |> String.to_integer(16), chain: @chain, chain_id: @chain_id}}
      {:error, reason} -> {:error, "Polygon block number fetch failed: #{reason}"}
    end
  end
  @impl true
  def fetch_gas_price do
    case rpc(@rpc_url, json_rpc(:eth_gasPrice, [])) do
      {:ok, %{"result" => gas_hex}} ->
        gas_wei = String.trim_leading(gas_hex, "0x") |> String.to_integer(16)
        {:ok, %{gas_price_wei: gas_wei, gas_price_gwei: gas_wei / 1_000_000_000, chain: @chain, chain_id: @chain_id}}
      {:error, reason} -> {:error, "Polygon gas price fetch failed: #{reason}"}
    end
  end
  @impl true
  def fetch_tx_count(address, block \\ "latest") do
    with {:ok, addr} <- validate_address(address) do
      case rpc(@rpc_url, json_rpc(:eth_getTransactionCount, [addr, block_to_hex(block)])) do
        {:ok, %{"result" => tx_hex}} ->
          {:ok, %{address: addr, tx_count: String.trim_leading(tx_hex, "0x") |> String.to_integer(16), block: block, chain: @chain}}
        {:error, reason} -> {:error, "Polygon tx count fetch failed: #{reason}"}
      end
    end
  end
  defp validate_address(address) do
    if Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address), do: {:ok, String.downcase(address)}, else: {:error, "Invalid address: #{address}"}
  end
  defp block_to_hex("latest"), do: "latest"
  defp block_to_hex("pending"), do: "pending"
  defp block_to_hex("earliest"), do: "earliest"
  defp block_to_hex(block) when is_integer(block) and block >= 0, do: "0x" <> Integer.to_string(block, 16)
  defp block_to_hex(block) when is_binary(block) and Regex.match?(~r/^0x[0-9a-fA-F]+$/, block), do: block
  defp block_to_hex(block), do: block_to_hex(String.to_integer(block))
  defp json_rpc(method, params), do: {:ok, %{jsonrpc: "2.0", method: method, params: params, id: 1}}
  defp rpc(url, payload) do
    body = Jason.encode!(payload)
    case :httpc.request(:post, {url, [], "application/json", body}, [], [body_format: :binary]) do
      {:ok, {{_, 200, _}, _, resp}} ->
        case Jason.decode(resp) do
          {:ok, %{"result" => result}} -> {:ok, %{result: result}}
          {:ok, %{"error" => error}} -> {:error, inspect(error)}
          {:error, reason} -> {:error, reason}
        end
      {:ok, {{_, status, _}, _, body_resp}} -> {:error, "HTTP #{status}: #{body_resp}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
