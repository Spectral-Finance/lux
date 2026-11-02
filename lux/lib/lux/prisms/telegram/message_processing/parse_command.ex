defmodule Lux.Prisms.Telegram.MessageProcessing.ParseCommand do
  @moduledoc """
  A prism for parsing Telegram bot commands, extracting command name, target bot,
  positional parameters, and GNU-style options/flags.
  """

  use Lux.Prism,
    name: "Parse Telegram Command",
    description: "Parses Telegram command strings and extracts arguments and flags",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Text containing the command"},
        bot_username: %{type: :string, description: "Optional bot username to filter commands"},
        prefix: %{type: :string, description: "Command prefix, default '/'"}
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        is_command: %{type: :boolean},
        command: %{type: :string},
        target_bot: %{type: :string},
        args: %{type: :array},
        options: %{type: :object},
        raw_args: %{type: :string}
      },
      required: ["is_command"]
    }

  alias Lux.Integrations.Telegram.MessageProcessing.CommandParser

  def handler(params, _agent) when is_map(params) do
    text = Map.get(params, :text) || Map.get(params, "text") || ""
    bot_username = Map.get(params, :bot_username) || Map.get(params, "bot_username")
    prefix = Map.get(params, :prefix) || Map.get(params, "prefix", "/")

    opts = [prefix: prefix]
    opts = if bot_username, do: [{:bot_username, bot_username} | opts], else: opts

    case CommandParser.parse(text, opts) do
      {:ok, result} ->
        {:ok, result}

      {:ignored, target_bot} ->
        {:ok, %{is_command: false, ignored_for_bot: target_bot, raw_text: text}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(_, _), do: {:error, "Invalid input: expected text parameter"}
end
