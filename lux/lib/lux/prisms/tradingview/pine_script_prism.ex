defmodule Lux.Prisms.TradingView.PineScriptPrism do
  @moduledoc """
  Prism for executing custom TradingView Pine Script rules and technical conditions.
  """

  use Lux.Prism,
    name: "TradingView Pine Script Prism",
    description: "Evaluates custom TradingView Pine Script rules and technical conditions",
    input_schema: %{
      type: :object,
      properties: %{
        script: %{
          type: :string,
          description: "Pine Script logic (e.g. 'close > ema and rsi < 70')"
        },
        context: %{type: :object, description: "Market data and indicator context map"}
      },
      required: ["script"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        result: %{type: :boolean},
        triggered?: %{type: :boolean},
        variables: %{type: :object}
      },
      required: ["result", "triggered?"]
    }

  alias Lux.TradingView.PineScript

  def handler(input, _ctx) do
    script = Map.get(input, :script) || Map.get(input, "script", "")
    context = Map.get(input, :context) || Map.get(input, "context", %{})

    case PineScript.execute(script, context) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, "Pine Script Prism execution error: #{reason}"}
    end
  end
end
