defmodule Lux.Unit.Prisms.TechnicalAnalysis.CustomScriptTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Prisms.TechnicalAnalysis.CustomScript

  describe "handler/2 - script evaluation" do
    test "evaluates SMA crossover expression" do
      closes = Enum.map(1..30, &(&1 * 1.0))

      input = %{
        script: "sma(close, fast) > sma(close, slow)",
        data: %{close: closes},
        params: %{fast: 5, slow: 10}
      }

      assert {:ok, result} = CustomScript.handler(input, nil)
      assert result.script_type == "expression"
      assert is_boolean(result.result) or is_tuple(result.result)
    end

    test "classifies strategy scripts" do
      input = %{
        script: "strategy.entry(\"long\", strategy.long)",
        data: %{close: [1, 2, 3, 4, 5]}
      }

      assert {:ok, result} = CustomScript.handler(input, nil)
      assert result.script_type == "strategy"
      assert result.interpretation =~ "hold" or result.interpretation =~ "Strategy"
    end

    test "classifies indicator scripts" do
      input = %{
        script: "plot(ta.sma(close, 20))",
        data: %{close: [1, 2, 3, 4, 5]}
      }

      assert {:ok, result} = CustomScript.handler(input, nil)
      assert result.script_type == "indicator"
    end

    test "handles unsupported scripts" do
      input = %{
        script: "some_unknown_complex_formula()",
        data: %{close: [1, 2, 3, 4, 5]}
      }

      assert {:ok, result} = CustomScript.handler(input, nil)
      assert result.result == {:unsupported, "some_unknown_complex_formula()"}
      assert result.interpretation =~ "Unsupported"
    end
  end

  describe "handler/2 - error cases" do
    test "missing data returns error" do
      input = %{script: "close > 50"}
      assert {:error, _msg} = CustomScript.handler(input, nil)
    end
  end
end
