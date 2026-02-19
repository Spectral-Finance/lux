defmodule Lux.Prisms.TradingView.CustomScriptTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.TradingView.CustomScript

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "run/1" do
    test "evaluates simple comparison script" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [28.5, 2.15, 1.80]
            }
          ]
        })
      end)

      assert {:ok, result} =
               CustomScript.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 screener: "america",
                 interval: "1d",
                 scripts: [
                   %{
                     name: "RSI Oversold",
                     conditions: [
                       %{left: "RSI", op: "<", right: 30}
                     ]
                   }
                 ]
               })

      assert result.symbol == "NASDAQ:TSLA"
      assert length(result.script_results) == 1

      [script_result] = result.script_results
      assert script_result.name == "RSI Oversold"
      assert script_result.result == true
      assert length(script_result.details) == 1

      [detail] = script_result.details
      assert detail.left_value == 28.5
      assert detail.right_value == 30
      assert detail.result == true
    end

    test "evaluates multi-condition script" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [28.5, 2.15, 1.80]
            }
          ]
        })
      end)

      assert {:ok, result} =
               CustomScript.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 scripts: [
                   %{
                     name: "RSI Oversold with MACD Bullish",
                     conditions: [
                       %{left: "RSI", op: "<", right: 30},
                       %{left: "MACD.macd", op: ">", right: "MACD.signal"}
                     ]
                   }
                 ]
               })

      [script_result] = result.script_results
      assert script_result.result == true
      assert length(script_result.details) == 2
    end

    test "evaluates script where condition is false" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [55.0]
            }
          ]
        })
      end)

      assert {:ok, result} =
               CustomScript.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 scripts: [
                   %{
                     name: "RSI Oversold",
                     conditions: [
                       %{left: "RSI", op: "<", right: 30}
                     ]
                   }
                 ]
               })

      [script_result] = result.script_results
      assert script_result.result == false
      assert result.all_true == false
    end

    test "evaluates multiple scripts" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [28.5, 245.0, 220.0]
            }
          ]
        })
      end)

      assert {:ok, result} =
               CustomScript.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 scripts: [
                   %{
                     name: "RSI Oversold",
                     conditions: [
                       %{left: "RSI", op: "<", right: 30}
                     ]
                   },
                   %{
                     name: "Golden Cross",
                     conditions: [
                       %{left: "EMA50", op: ">", right: "SMA200"}
                     ]
                   }
                 ]
               })

      assert length(result.script_results) == 2
      assert result.all_true == true
    end

    test "supports numeric literals on both sides" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [50.0]
            }
          ]
        })
      end)

      assert {:ok, result} =
               CustomScript.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 scripts: [
                   %{
                     name: "Always True",
                     conditions: [
                       %{left: 10, op: "<", right: 20}
                     ]
                   }
                 ]
               })

      assert result.all_true == true
    end

    test "supports all comparison operators" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [50.0]
            }
          ]
        })
      end)

      assert {:ok, result} =
               CustomScript.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 scripts: [
                   %{
                     name: "Operator Test",
                     conditions: [
                       %{left: "RSI", op: ">=", right: 50},
                       %{left: "RSI", op: "<=", right: 50},
                       %{left: "RSI", op: "==", right: 50},
                       %{left: "RSI", op: "!=", right: 30}
                     ]
                   }
                 ]
               })

      assert result.all_true == true
    end

    test "includes indicator values in response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [28.5, 2.15]
            }
          ]
        })
      end)

      assert {:ok, result} =
               CustomScript.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 scripts: [
                   %{
                     name: "Test",
                     conditions: [
                       %{left: "RSI", op: "<", right: 30},
                       %{left: "MACD.macd", op: ">", right: 0}
                     ]
                   }
                 ]
               })

      assert result.indicator_values["RSI"] == 28.5
      assert result.indicator_values["MACD.macd"] == 2.15
    end

    test "handles missing data gracefully" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [nil]
            }
          ]
        })
      end)

      assert {:ok, result} =
               CustomScript.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 scripts: [
                   %{
                     name: "Nil Test",
                     conditions: [
                       %{left: "RSI", op: "<", right: 30}
                     ]
                   }
                 ]
               })

      [script_result] = result.script_results
      assert script_result.result == false
    end

    test "returns error when no data available" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"data" => []})
      end)

      assert {:error, "No data returned for NASDAQ:TSLA"} =
               CustomScript.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 scripts: [
                   %{
                     name: "Test",
                     conditions: [%{left: "RSI", op: "<", right: 30}]
                   }
                 ]
               })
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = CustomScript.view()

      assert prism.name == "TradingView Custom Script"
      assert "symbol" in prism.input_schema.required
      assert "exchange" in prism.input_schema.required
      assert "scripts" in prism.input_schema.required
    end

    test "validates output schema" do
      prism = CustomScript.view()

      assert "symbol" in prism.output_schema.required
      assert "script_results" in prism.output_schema.required
      assert "all_true" in prism.output_schema.required
    end
  end
end
