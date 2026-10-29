defmodule Lux.Prisms.TradingView.AlertManagerTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.TradingView.AlertManager

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "run/1 with threshold conditions" do
    test "triggers alert when RSI is below threshold" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.32, 0.45, 0.12, 28.5]
            }
          ]
        })
      end)

      assert {:ok, result} =
               AlertManager.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 screener: "america",
                 interval: "1d",
                 conditions: [
                   %{type: "threshold", indicator: "RSI", operator: "below", value: 30}
                 ]
               })

      assert result.symbol == "NASDAQ:TSLA"
      assert result.any_triggered == true
      assert length(result.alerts_triggered) == 1
      assert length(result.alerts_not_triggered) == 0

      [alert] = result.alerts_triggered
      assert alert.triggered == true
      assert alert.current_value == 28.5
      assert alert.condition == "RSI below 30"
    end

    test "does not trigger alert when condition is not met" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.32, 0.45, 0.12, 55.0]
            }
          ]
        })
      end)

      assert {:ok, result} =
               AlertManager.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 conditions: [
                   %{type: "threshold", indicator: "RSI", operator: "below", value: 30}
                 ]
               })

      assert result.any_triggered == false
      assert length(result.alerts_triggered) == 0
      assert length(result.alerts_not_triggered) == 1
    end

    test "evaluates multiple threshold conditions" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.32, 0.45, 0.12, 28.5, 253.80]
            }
          ]
        })
      end)

      assert {:ok, result} =
               AlertManager.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 conditions: [
                   %{type: "threshold", indicator: "RSI", operator: "below", value: 30},
                   %{type: "threshold", indicator: "close", operator: "above", value: 260.0}
                 ]
               })

      assert result.any_triggered == true
      assert length(result.alerts_triggered) == 1
      assert length(result.alerts_not_triggered) == 1
    end

    test "supports above operator" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.32, 0.45, 0.12, 253.80]
            }
          ]
        })
      end)

      assert {:ok, result} =
               AlertManager.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 conditions: [
                   %{type: "threshold", indicator: "close", operator: "above", value: 250.0}
                 ]
               })

      assert result.any_triggered == true
    end
  end

  describe "run/1 with crossover conditions" do
    test "detects crossover above" do
      # Columns order: Recommend.All, Recommend.MA, Recommend.Other, MACD.signal, MACD.macd
      # (indicator2 comes before indicator in extract_needed_indicators)
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.32, 0.45, 0.12, 1.80, 2.15]
            }
          ]
        })
      end)

      assert {:ok, result} =
               AlertManager.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 conditions: [
                   %{
                     type: "crossover",
                     indicator: "MACD.macd",
                     indicator2: "MACD.signal",
                     operator: "crosses_above"
                   }
                 ]
               })

      assert result.any_triggered == true
      [alert] = result.alerts_triggered
      assert alert.current_value.indicator1 == 2.15
      assert alert.current_value.indicator2 == 1.80
    end

    test "detects crossover below" do
      # Columns order: Recommend.All, Recommend.MA, Recommend.Other, MACD.signal, MACD.macd
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.32, 0.45, 0.12, 2.10, 1.50]
            }
          ]
        })
      end)

      assert {:ok, result} =
               AlertManager.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 conditions: [
                   %{
                     type: "crossover",
                     indicator: "MACD.macd",
                     indicator2: "MACD.signal",
                     operator: "crosses_below"
                   }
                 ]
               })

      assert result.any_triggered == true
    end
  end

  describe "run/1 with recommendation conditions" do
    test "triggers when recommendation matches target" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.55, 0.65, 0.38]
            }
          ]
        })
      end)

      assert {:ok, result} =
               AlertManager.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 conditions: [
                   %{type: "recommendation", target: "STRONG_BUY"}
                 ]
               })

      assert result.any_triggered == true
    end

    test "does not trigger when recommendation does not match" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.05, 0.10, -0.02]
            }
          ]
        })
      end)

      assert {:ok, result} =
               AlertManager.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 conditions: [
                   %{type: "recommendation", target: "STRONG_BUY"}
                 ]
               })

      assert result.any_triggered == false
    end
  end

  describe "run/1 error handling" do
    test "returns error when no data available" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"data" => []})
      end)

      assert {:error, "No data returned for NASDAQ:TSLA"} =
               AlertManager.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 conditions: [
                   %{type: "threshold", indicator: "RSI", operator: "below", value: 30}
                 ]
               })
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = AlertManager.view()

      assert prism.name == "TradingView Alert Manager"
      assert "symbol" in prism.input_schema.required
      assert "exchange" in prism.input_schema.required
      assert "conditions" in prism.input_schema.required
    end

    test "validates output schema" do
      prism = AlertManager.view()

      assert "symbol" in prism.output_schema.required
      assert "any_triggered" in prism.output_schema.required
    end
  end
end
