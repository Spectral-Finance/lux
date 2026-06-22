defmodule Lux.Prisms.YouTube.GrowthPredictorPrism do
  @moduledoc """
  A prism that predicts future subscriber growth based on current statistics.
  """

  use Lux.Prism,
    name: "YouTube Growth Predictor",
    description: "Predicts future subscriber growth for a YouTube channel",
    input_schema: %{
      type: :object,
      properties: %{
        current_subscribers: %{
          type: :integer,
          description: "Current number of subscribers"
        },
        historical_growth_rate: %{
          type: :number,
          description: "Monthly growth rate as a decimal (e.g., 0.05 for 5%)",
          default: 0.05
        },
        months_to_predict: %{
          type: :integer,
          description: "Number of months to predict into the future",
          default: 12
        }
      },
      required: ["current_subscribers"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        predicted_subscribers: %{
          type: :integer,
          description: "Predicted number of subscribers"
        },
        growth_trajectory: %{
          type: :array,
          items: %{type: :integer},
          description: "Monthly predicted subscribers"
        }
      },
      required: ["predicted_subscribers", "growth_trajectory"]
    }

  def handler(input, _ctx) do
    subs = Map.get(input, :current_subscribers)
    rate = Map.get(input, :historical_growth_rate, 0.05)
    months = Map.get(input, :months_to_predict, 12)

    trajectory =
      Enum.reduce(1..months, [subs], fn _, [last | _] = acc ->
        [round(last * (1 + rate)) | acc]
      end)
      |> Enum.reverse()
      |> tl() # Remove the initial value

    predicted = List.last(trajectory) || subs

    {:ok, %{
      predicted_subscribers: predicted,
      growth_trajectory: trajectory
    }}
  end
end
