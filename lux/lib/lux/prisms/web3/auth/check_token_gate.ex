defmodule Lux.Prisms.Web3.Auth.CheckTokenGatePrism do
  @moduledoc """
  Evaluates token-gated access rules for a wallet address.
  """

  use Lux.Prism,
    name: "Check Token Gate",
    description: "Evaluates ERC-20, ERC-721, ERC-1155, or native token balance gates for access control",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{type: :string, description: "Wallet address to verify"},
        operator: %{type: :string, enum: ["all", "any", "none"], default: "all"},
        rules: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              type: %{type: :string, enum: ["erc20", "erc721", "erc1155", "native"]},
              contract: %{type: :string},
              min_balance: %{type: :integer},
              token_id: %{type: :integer},
              chain_id: %{type: :integer}
            },
            required: ["type"]
          }
        },
        balances: %{type: :object, description: "Map of pre-fetched balances by contract address or token type"}
      },
      required: ["address", "rules"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        allowed: %{type: :boolean},
        address: %{type: :string},
        matched_count: %{type: :integer},
        missing_count: %{type: :integer}
      },
      required: ["allowed", "address"]
    }

  alias Lux.Web3.Auth.TokenGating

  def handler(input, _ctx) do
    address = Map.get(input, :address) || Map.get(input, "address")
    raw_operator = Map.get(input, :operator) || Map.get(input, "operator", "all")
    raw_rules = Map.get(input, :rules) || Map.get(input, "rules", [])
    balances = Map.get(input, :balances) || Map.get(input, "balances", %{})

    operator =
      case to_string(raw_operator) do
        "any" -> :any
        "none" -> :none
        _ -> :all
      end

    rules =
      Enum.map(raw_rules, fn r ->
        type_str = Map.get(r, :type) || Map.get(r, "type", "erc20")
        type = String.to_atom(to_string(type_str))
        contract = Map.get(r, :contract) || Map.get(r, "contract")
        min_balance = Map.get(r, :min_balance) || Map.get(r, "min_balance", 1)
        token_id = Map.get(r, :token_id) || Map.get(r, "token_id")
        chain_id = Map.get(r, :chain_id) || Map.get(r, "chain_id", 1)

        %{
          type: type,
          contract: if(contract, do: String.downcase(contract), else: nil),
          min_balance: min_balance,
          token_id: token_id,
          chain_id: chain_id,
          description: "#{type} requirement"
        }
      end)

    gate_spec = %{operator: operator, rules: rules}

    case TokenGating.evaluate_gate(address, gate_spec, balances) do
      {:ok, %{allowed: true, matched_rules: matched}} ->
        {:ok,
         %{
           allowed: true,
           address: address,
           matched_count: length(matched),
           missing_count: 0
         }}

      {:error, :access_denied, %{missing_rules: missing}} ->
        {:ok,
         %{
           allowed: false,
           address: address,
           matched_count: length(rules) - length(missing),
           missing_count: length(missing)
         }}
    end
  end
end
