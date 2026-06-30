defmodule Lux.Prisms.Telegram.ParseCommand do
  @moduledoc """
  A prism that parses a Telegram command from raw text.
  """
  use Lux.Prism,
    name: "Parse Telegram Command",
    description: "Parses a Telegram command (e.g. /start --key value) and extracts arguments and flags.",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Raw command text from Telegram"}
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        command: %{type: :string},
        args: %{type: :array, items: %{type: :string}},
        raw_args: %{type: :string},
        flags: %{type: :object}
      }
    }

  def handler(%{"text" => text}, _ctx) do
    Lux.Integrations.Telegram.CommandParser.parse(text)
  end
end
