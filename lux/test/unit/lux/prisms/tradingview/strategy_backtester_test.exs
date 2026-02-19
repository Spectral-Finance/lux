defmodule Lux.Prisms.TradingView.StrategyBacktesterTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.TradingView.StrategyBacktester

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "run/1" do
    test "evaluates strategy with entry conditions met" do
      # Expect one scan call per interval (3 intervals)
      for _i <- 1..3 do
        Req.Test.expect(Lux.Lens, fn conn ->
          Req.Test.json(conn, %{
            "data" => [
              %{
                "s" => "NASDAQ:TSLA",
                "d" => [28.5, 2.15, 1.80, 253.80]
              }
            ]
          })
        end)
      end

      assert {:ok, result} =
               StrategyBacktester.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 screener: "america",
                 strategy: %{
                   name: "RSI Reversal",
                   entry_conditions: [
                     %{indicator: "RSI", operator: "below", value: 30},
                     %{indicator: "MACD.macd", operator: "above", value2: "MACD.signal"}
                   ],
                   exit_conditions: [
                     %{indicator: "RSI", operator: "above", value: 70}
                   ],
                   stop_loss_pct: 5.0,
                   take_profit_pct: 15.0
                 },
                 intervals: ["1h", "4h", "1d"]
               })

      assert result.symbol == "NASDAQ:TSLA"
      assert result.strategy_name == "RSI Reversal"
      assert result.current_price == 253.80
      assert is_number(result.stop_loss_price)
      assert is_number(result.take_profit_price)
      assert result.risk_reward_ratio == 3.0
      assert result.overall_signal in ["ENTRY", "EXIT", "HOLD", "NO_SIGNAL"]

      # Verify timeframe results
      assert map_size(result.timeframe_results) == 3

      for {_interval, tf_result} <- result.timeframe_results do
        assert Map.has_key?(tf_result, :entry_met)
        assert Map.has_key?(tf_result, :exit_met)
        assert Map.has_key?(tf_result, :entry_details)
        assert Map.has_key?(tf_result, :exit_details)
      end
    end

    test "calculates stop loss and take profit correctly" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [50.0, 200.0]
            }
          ]
        })
      end)

      assert {:ok, result} =
               StrategyBacktester.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 strategy: %{
                   name: "Test Strategy",
                   entry_conditions: [
                     %{indicator: "RSI", operator: "below", value: 60}
                   ],
                   stop_loss_pct: 5.0,
                   take_profit_pct: 10.0
                 },
                 intervals: ["1d"]
               })

      assert result.current_price == 200.0
      assert result.stop_loss_price == 190.0
      assert result.take_profit_price == 220.0
      assert result.risk_reward_ratio == 2.0
    end

    test "detects entry signal when all conditions met across majority of timeframes" do
      # All timeframes show entry conditions met
      for _i <- 1..2 do
        Req.Test.expect(Lux.Lens, fn conn ->
          Req.Test.json(conn, %{
            "data" => [
              %{
                "s" => "NASDAQ:TSLA",
                "d" => [25.0, 253.80]  # RSI=25, close=253.80
              }
            ]
          })
        end)
      end

      assert {:ok, result} =
               StrategyBacktester.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 strategy: %{
                   name: "Simple RSI",
                   entry_conditions: [
                     %{indicator: "RSI", operator: "below", value: 30}
                   ],
                   stop_loss_pct: 3.0,
                   take_profit_pct: 9.0
                 },
                 intervals: ["1h", "1d"]
               })

      assert result.overall_signal == "ENTRY"
    end

    test "shows no signal when no conditions met" do
      for _i <- 1..2 do
        Req.Test.expect(Lux.Lens, fn conn ->
          Req.Test.json(conn, %{
            "data" => [
              %{
                "s" => "NASDAQ:TSLA",
                "d" => [55.0, 253.80]
              }
            ]
          })
        end)
      end

      assert {:ok, result} =
               StrategyBacktester.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 strategy: %{
                   name: "Simple RSI",
                   entry_conditions: [
                     %{indicator: "RSI", operator: "below", value: 30}
                   ],
                   stop_loss_pct: 5.0,
                   take_profit_pct: 10.0
                 },
                 intervals: ["1h", "1d"]
               })

      assert result.overall_signal == "NO_SIGNAL"
    end

    test "handles crossover conditions using value2" do
      # Columns order: MACD.signal, MACD.macd, close
      # (value2 indicator comes before indicator in extract_strategy_columns)
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [1.80, 2.15, 253.80]
            }
          ]
        })
      end)

      assert {:ok, result} =
               StrategyBacktester.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 strategy: %{
                   name: "MACD Crossover",
                   entry_conditions: [
                     %{indicator: "MACD.macd", operator: "above", value2: "MACD.signal"}
                   ],
                   stop_loss_pct: 5.0,
                   take_profit_pct: 10.0
                 },
                 intervals: ["1d"]
               })

      # MACD.macd (2.15) > MACD.signal (1.80) → entry met
      tf = result.timeframe_results["1d"]
      assert tf.entry_met == true
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = StrategyBacktester.view()

      assert prism.name == "TradingView Strategy Backtester"
      assert "symbol" in prism.input_schema.required
      assert "exchange" in prism.input_schema.required
      assert "strategy" in prism.input_schema.required
    end

    test "validates output schema" do
      prism = StrategyBacktester.view()

      assert "symbol" in prism.output_schema.required
      assert "strategy_name" in prism.output_schema.required
      assert "overall_signal" in prism.output_schema.required
    end
  end
end
