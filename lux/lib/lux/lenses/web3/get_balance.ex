defmodule Lux.Lenses.Web3.GetBalance do
  @moduledoc """
  Lens for fetching ETH balance across multiple EVM chains.
  """

  alias Lux.Integrations.Web3.WalletManager

  @chains WalletManager.supported_chains()

  def focus(params, _opts \\ []) do
    address = params[:address] || params["address"]
    chain = to_chain(params[:chain] || params["chain"] || "ethereum")
    plug = params[:plug]

    case Map.get(@chains, chain) do
      nil ->
        {:error, "Unsupported chain: #{inspect(chain)}"}

      config ->
        fetch_balance(address, config, plug)
    end
  end

  defp fetch_balance(address, config, plug) do
    body =
      Jason.encode!(%{
        jsonrpc: "2.0",
        id: 1,
        method: "eth_getBalance",
        params: [address, "latest"]
      })

    req_opts = [
      body: body,
      headers: [{"content-type", "application/json"}],
      receive_timeout: 10_000,
      retry: false
    ]

    req_opts = if plug, do: Keyword.put(req_opts, :plug, plug), else: req_opts

    case Req.post(config.rpc, req_opts) do
      {:ok, %{status: 200, body: %{"result" => hex_balance}}} ->
        wei = hex_to_integer(hex_balance)
        eth = wei / 1.0e18

        {:ok, %{
          address: address,
          balance_wei: wei,
          balance: Float.round(eth, 8),
          symbol: config.symbol,
          chain: to_string(find_chain_name(config.chain_id))
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

  defp find_chain_name(id) do
    Enum.find_value(@chains, :unknown, fn {name, config} ->
      if config.chain_id == id, do: name
    end)
  end
end
