defmodule Lux.Prisms.Telegram.Processing.ParseCommand do
  @moduledoc """
  Parses Telegram commands and extracts parameters.
  """
  use Lux.Prism,
    name: "Parse Telegram Command",
    description: "Parses a Telegram command message and extracts the command and its parameters",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Message text containing a command"},
        bot_username: %{type: :string, description: "Optional bot username to validate commands directed at this bot (e.g. /cmd@bot)"}
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        is_command: %{type: :boolean},
        command: %{type: :string},
        args: %{
          type: :array,
          items: %{type: :string}
        }
      },
      required: ["is_command"]
    }

  def handler(params, _ctx) do
    text = Map.get(params, :text) || Map.get(params, "text") || ""
    bot_username = Map.get(params, :bot_username) || Map.get(params, "bot_username")
    text = String.trim(text)

    if String.starts_with?(text, "/") do
      [cmd_part | args] = String.split(text, " ", trim: true)
      
      {is_valid, command} = 
        case String.split(cmd_part, "@") do
          [cmd] -> {true, String.slice(cmd, 1..-1//1)}
          [cmd, target] -> 
            if is_nil(bot_username) or String.downcase(target) == String.downcase(bot_username) do
              {true, String.slice(cmd, 1..-1//1)}
            else
              {false, nil}
            end
          _ -> {false, nil}
        end

      if is_valid do
        {:ok, %{is_command: true, command: command, args: args}}
      else
        {:ok, %{is_command: false}}
      end
    else
      {:ok, %{is_command: false}}
    end
  end
end
