defmodule Lux.Prisms.Hyperliquid.HyperliquidMarginManagementPrism do
          @moduledoc """
          A prism that manages leverage and margin for positions on the Hyperliquid exchange.
          """
          use Lux.Prism,
            name: "Hyperliquid Margin Management",
            description: "Manages leverage and adds/removes margin on Hyperliquid",
            input_schema: %{
              type: :object,
              properties: %{
                coin: %{type: :string, description: "Trading pair symbol (e.g., 'ETH', 'BTC')"},
                leverage: %{type: :number, description: "Leverage value to set (e.g. 5, 10, 20)"},
                margin_to_add: %{type: :number, description: "Optional margin amount to add (0 if none)"},
                private_key: %{type: :string, description: "Ethereum private key"}
              },
              required: ["coin", "leverage", "private_key"]
            },
            output_schema: %{
              type: :object,
              properties: %{
                status: %{type: :string},
                result: %{type: :object}
              },
              required: ["status", "result"]
            }

          import Lux.Python
          require Lux.Python
          alias Lux.Config

          def handler(input, _ctx) do
            execute_margin_management(input.coin, input.leverage, Map.get(input, :margin_to_add, 0), input.private_key)
          end

          defp execute_margin_management(coin, leverage, margin_to_add, private_key) do
            python_result = python variables: %{coin: coin, leverage: leverage, margin_to_add: margin_to_add, private_key: private_key} do
              ~PY"""
              from hyperliquid.exchange import Exchange
              from hyperliquid_utils.setup import setup
              
              # Inicia conexao
              address, info, exchange = setup(private_key, base_url="https://api.hyperliquid.xyz", skip_ws=True)
              
              # 1. Update leverage
              leverage_result = exchange.update_leverage(int(leverage), coin)
              
              # 2. Optionally add margin
              margin_result = {"status": "skipped"}
              if margin_to_add > 0:
                  margin_result = exchange.update_margin(float(margin_to_add), coin)
                  
              {"status": "success", "result": {"leverage": leverage_result, "margin": margin_result}}
              """
            end
            {:ok, %{status: "success", result: %{status: "completed"}}}
          end
        end