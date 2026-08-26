defmodule LuxApp.TxManager.RPCAdapter do
  @moduledoc """
  Behaviour for Ethereum RPC interactions, allowing dependency injection.
  """

  @callback get_base_fee() :: {:ok, integer()} | {:error, any()}
  @callback estimate_gas(map()) :: {:ok, integer()} | {:error, any()}
  @callback send_transaction(map()) :: {:ok, String.t()} | {:error, any()}
  @callback send_private_transaction(map(), String.t()) :: {:ok, String.t()} | {:error, any()}
  @callback get_transaction_receipt(String.t()) :: {:ok, map()} | {:error, any()}
end

defmodule LuxApp.TxManager.RealRPC do
  @moduledoc """
  Production implementation of RPCAdapter executing real EVM JSON-RPC calls via Finch.
  Properly propagates transport, decode, and contract revert errors.
  """
  @behaviour LuxApp.TxManager.RPCAdapter

  @impl true
  def get_base_fee do
    rpc_url = Application.get_env(:lux_app, :ethereum_rpc_url, "http://127.0.0.1:8545")
    payload = Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => "eth_getBlockByNumber",
      "params" => ["latest", false],
      "id" => 1
    })

    case post_rpc(rpc_url, payload) do
      {:ok, %{"result" => %{"baseFeePerGas" => hex_fee}}} when is_binary(hex_fee) ->
        {fee, _} = Integer.parse(String.replace(hex_fee, "0x", ""), 16)
        {:ok, fee}

      {:ok, %{"result" => %{"gasPrice" => hex_fee}}} when is_binary(hex_fee) ->
        {fee, _} = Integer.parse(String.replace(hex_fee, "0x", ""), 16)
        {:ok, fee}

      {:ok, %{"error" => rpc_err}} ->
        {:error, {:rpc_error, rpc_err}}

      error ->
        error
    end
  end

  @impl true
  def estimate_gas(tx) do
    rpc_url = Application.get_env(:lux_app, :ethereum_rpc_url, "http://127.0.0.1:8545")
    payload = Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => "eth_estimateGas",
      "params" => [format_tx_param(tx)],
      "id" => 1
    })

    case post_rpc(rpc_url, payload) do
      {:ok, %{"result" => hex_gas}} when is_binary(hex_gas) ->
        {gas, _} = Integer.parse(String.replace(hex_gas, "0x", ""), 16)
        {:ok, gas}

      {:ok, %{"error" => rpc_err}} ->
        {:error, {:execution_reverted, rpc_err}}

      error ->
        error
    end
  end

  @impl true
  def send_transaction(tx) do
    raw_tx_hex = Map.get(tx, :raw_tx) || Map.get(tx, "raw_tx") || "0x"
    rpc_url = Application.get_env(:lux_app, :ethereum_rpc_url, "http://127.0.0.1:8545")
    payload = Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => "eth_sendRawTransaction",
      "params" => [raw_tx_hex],
      "id" => 1
    })

    case post_rpc(rpc_url, payload) do
      {:ok, %{"result" => tx_hash}} when is_binary(tx_hash) ->
        {:ok, tx_hash}

      {:ok, %{"error" => %{"message" => msg}}} ->
        if String.contains?(String.downcase(msg), "replacement transaction underpriced") do
          {:error, :replacement_underpriced}
        else
          {:error, {:rpc_error, msg}}
        end

      error ->
        error
    end
  end

  @impl true
  def send_private_transaction(tx, builder) do
    relay_url = Application.get_env(:lux_app, :mev_relay_url, "http://127.0.0.1:8545")
    raw_tx_hex = Map.get(tx, :raw_tx) || Map.get(tx, "raw_tx") || "0x"

    payload = Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => "eth_sendPrivateTransaction",
      "params" => [%{"tx" => raw_tx_hex, "builder" => builder}],
      "id" => 1
    })

    case post_rpc(relay_url, payload) do
      {:ok, %{"result" => tx_hash}} when is_binary(tx_hash) ->
        {:ok, tx_hash}

      {:ok, %{"error" => rpc_err}} ->
        {:error, {:private_relay_error, rpc_err}}

      error ->
        error
    end
  end

  @impl true
  def get_transaction_receipt(hash) do
    rpc_url = Application.get_env(:lux_app, :ethereum_rpc_url, "http://127.0.0.1:8545")
    payload = Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => "eth_getTransactionReceipt",
      "params" => [hash],
      "id" => 1
    })

    case post_rpc(rpc_url, payload) do
      {:ok, %{"result" => receipt}} when is_map(receipt) ->
        {:ok, receipt}

      {:ok, %{"result" => nil}} ->
        {:ok, nil}

      {:ok, %{"error" => rpc_err}} ->
        {:error, {:rpc_error, rpc_err}}

      error ->
        error
    end
  end

  defp post_rpc(rpc_url, payload) do
    req = Finch.build(:post, rpc_url, [{"content-type", "application/json"}], payload)

    case Finch.request(req, LuxApp.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, json} -> {:ok, json}
          _ -> {:error, :invalid_json}
        end

      {:ok, %Finch.Response{status: code}} ->
        {:error, {:http_error, code}}

      {:error, reason} ->
        {:error, {:network_failure, reason}}
    end
  end

  defp format_tx_param(tx) do
    %{
      "from" => Map.get(tx, :from) || Map.get(tx, "from"),
      "to" => Map.get(tx, :to) || Map.get(tx, "to"),
      "data" => Map.get(tx, :data) || Map.get(tx, "data", "0x"),
      "value" => format_hex(Map.get(tx, :value) || Map.get(tx, "value", 0))
    }
  end

  defp format_hex(val) when is_integer(val), do: "0x" <> Integer.to_string(val, 16)
  defp format_hex(val) when is_binary(val), do: val
end

defmodule LuxApp.TxManager.MockRPC do
  @moduledoc "Mock implementation of RPCAdapter strictly for testing environments."
  @behaviour LuxApp.TxManager.RPCAdapter

  @impl true
  def get_base_fee, do: {:ok, 30_000_000_000}

  @impl true
  def estimate_gas(tx) do
    to = Map.get(tx, :to) || Map.get(tx, "to")
    if to == "0xbad", do: {:error, :execution_reverted}, else: {:ok, 21_000}
  end

  @impl true
  def send_transaction(tx) do
    if Map.get(tx, :simulated_error) == :replacement_underpriced do
      {:error, :replacement_underpriced}
    else
      {:ok, "0x" <> Base.encode16(:crypto.strong_rand_bytes(32), case: :lower)}
    end
  end

  @impl true
  def send_private_transaction(_tx, _builder) do
    {:ok, "0x" <> Base.encode16(:crypto.strong_rand_bytes(32), case: :lower)}
  end

  @impl true
  def get_transaction_receipt(hash) do
    {:ok, %{"status" => "0x1", "transactionHash" => hash}}
  end
end
