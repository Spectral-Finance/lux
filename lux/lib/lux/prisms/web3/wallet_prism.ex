defmodule Lux.Prisms.Web3.WalletPrism do
  @moduledoc """
  Lux Prism exposing Web3 wallet creation, import, HD account derivation,
  multi-chain balance monitoring, and transaction building/signing/queueing
  for autonomous agents.
  """

  use Lux.Prism,
    name: "Web3 Wallet & Transaction Manager",
    description: "Creates and manages multi-chain EVM wallets and transactions",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Wallet or transaction action to execute"
        },
        wallet_id: %{type: :string, description: "Target wallet identifier"},
        wallet_type: %{type: :string, description: "standard, hd, hardware, or multisig"},
        chains: %{type: :array, items: %{type: :string}},
        to: %{type: :string, description: "Recipient checksummed EVM address"},
        value: %{type: :integer, description: "Transfer amount in wei"},
        chain: %{type: :string, description: "Target chain name (e.g. ethereum, polygon)"}
      },
      required: ["action"]
    }

  alias Lux.Web3.Transaction
  alias Lux.Web3.Wallet

  @impl true
  def handler(params, _ctx) when is_map(params) do
    action = Map.get(params, "action") || Map.get(params, :action)
    dispatch(to_string(action), normalize_keys(params))
  end

  defp dispatch("create_wallet", params) do
    type = parse_wallet_type(Map.get(params, :wallet_type, "standard"))
    Wallet.create(Map.put(params, :type, type))
  end

  defp dispatch("import_wallet", params) do
    Wallet.import_wallet(params)
  end

  defp dispatch("derive_account", %{wallet_id: wallet_id} = params) do
    index = Map.get(params, :index, 1)

    case Wallet.derive_account(wallet_id, index) do
      {:ok, account, _wallet} -> {:ok, account}
      error -> error
    end
  end

  defp dispatch("get_balances", %{wallet_id: wallet_id} = params) do
    chains =
      params
      |> Map.get(:chains, [:ethereum, :polygon, :arbitrum])
      |> Enum.map(&parse_chain/1)

    Wallet.get_multi_chain_balances(wallet_id, chains)
  end

  defp dispatch("build_and_sign_tx", %{wallet_id: wallet_id} = params) do
    chain = parse_chain(Map.get(params, :chain, :ethereum))

    with {:ok, tx} <- Transaction.build(wallet_id, Map.put(params, :chain, chain)) do
      Transaction.sign(tx)
    end
  end

  defp dispatch("list_transactions", params) do
    filters =
      if is_binary(params[:wallet_id]) do
        [wallet_id: params[:wallet_id]]
      else
        []
      end

    {:ok, Transaction.list_transactions(filters)}
  end

  defp dispatch(other, _params), do: {:error, {:unsupported_action, other}}

  defp parse_wallet_type(type) when is_atom(type), do: type
  defp parse_wallet_type("hd"), do: :hd
  defp parse_wallet_type("hardware"), do: :hardware
  defp parse_wallet_type("multisig"), do: :multisig
  defp parse_wallet_type(_), do: :standard

  defp parse_chain(chain) when is_atom(chain), do: chain
  defp parse_chain("ethereum"), do: :ethereum
  defp parse_chain("polygon"), do: :polygon
  defp parse_chain("arbitrum"), do: :arbitrum
  defp parse_chain("optimism"), do: :optimism
  defp parse_chain("base"), do: :base
  defp parse_chain("bsc"), do: :bsc
  defp parse_chain("avalanche"), do: :avalanche
  defp parse_chain("sepolia"), do: :sepolia
  defp parse_chain(_), do: :ethereum

  defp normalize_keys(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end
end
