defmodule Lux.Lenses.Web3.GetTransactionStatus do
  @moduledoc """
  Lens for checking transaction status and receipt on EVM chains.
  """

  alias Lux.Integrations.Web3.WalletManager

  @chains WalletManager.supported_chains()

  def focus(params, _opts \\ []) do
    tx_hash = params[:tx_hash] || params["tx_hash"]
    chain = to_chain(params[:chain] || params["chain"] || "ethereum")
    plug = params[:plug]

    case Map.get(@chains, chain) do
      nil ->
        {:error, "Unsupported chain: #{inspect(chain)}"}

      config ->
        fetch_receipt(tx_hash, config, plug)
    end
  end

  defp fetch_receipt(tx_hash, config, plug) do
    body =
      Jason.encode!(%{
        jsonrpc: "2.0",
        id: 1,
        method: "eth_getTransactionReceipt",
        params: [tx_hash]
      })

    req_opts = [
      body: body,
      headers: [{"content-type", "application/json"}],
      receive_timeout: 10_000,
      retry: false
    ]

    req_opts = if plug, do: Keyword.put(req_opts, :plug, plug), else: req_opts

    case Req.post(config.rpc, req_opts) do
      {:ok, %{status: 200, body: %{"result" => nil}}} ->
        {:ok, %{tx_hash: tx_hash, status: :pending}}

      {:ok, %{status: 200, body: %{"result" => receipt}}} ->
        status = if receipt["status"] == "0x1", do: :confirmed, else: :failed

        {:ok, %{
          tx_hash: tx_hash,
          status: status,
          block_number: hex_to_integer(receipt["blockNumber"] || "0x0"),
          gas_used: hex_to_integer(receipt["gasUsed"] || "0x0"),
          from: receipt["from"],
          to: receipt["to"],
          contract_address: receipt["contractAddress"]
        }}

      {:ok, %{body: %{"error" => error}}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp hex_to_integer("0x"), do: 0
  defp hex_to_integer("0x" <> hex), do: String.to_integer(hex, 16)

  defp to_chain(c) when is_atom(c), do: c
  defp to_chain(c) when is_binary(c), do: String.to_existing_atom(c)
end
