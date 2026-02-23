defmodule Lux.Prisms.Telegram.Messages.ParseCommand do
  @moduledoc """
  A prism for parsing Telegram bot commands from message text.

  Parses commands in the format `/command@bot arg1 arg2` and extracts
  the command name, optional bot username target, and arguments.

  ## Implementation Details

  - Handles `/command`, `/command@botname`, `/COMMAND` (case-insensitive)
  - Extracts space-separated arguments after the command
  - Returns structured data for easy routing in bot logic
  - Pure computation — no API call required

  ## Examples

      iex> ParseCommand.handler(%{text: "/start"}, %{name: "Agent"})
      {:ok, %{command: "start", bot_target: nil, args: [], raw: "/start"}}

      iex> ParseCommand.handler(%{text: "/help@mybot arg1 arg2"}, %{name: "Agent"})
      {:ok, %{command: "help", bot_target: "mybot", args: ["arg1", "arg2"], raw: "/help@mybot arg1 arg2"}}

      iex> ParseCommand.handler(%{text: "Hello, not a command"}, %{name: "Agent"})
      {:error, "Text does not start with a bot command"}
  """

  use Lux.Prism,
    name: "Parse Telegram Command",
    description: "Parses a Telegram bot command from message text, extracting command name, bot target, and arguments",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "Message text to parse for a bot command"
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        command: %{type: :string, description: "The command name (without /)"},
        bot_target: %{type: [:string, :null], description: "The bot username if @bot was specified"},
        args: %{type: :array, items: %{type: :string}, description: "List of arguments after the command"},
        raw: %{type: :string, description: "The original command portion of the text"}
      }
    }

  @command_regex ~r/^\/([A-Za-z0-9_]+)(?:@([A-Za-z0-9_]+))?\s*(.*)?$/s

  @impl true
  def handler(%{text: text} = _params, _agent) do
    text = to_string(text) |> String.trim()

    case Regex.run(@command_regex, text) do
      [raw_command | captures] ->
        {cmd, bot_target, rest} = parse_captures(captures)
        args = parse_args(rest)
        raw = String.split(raw_command, " ") |> List.first()

        {:ok, %{
          command: String.downcase(cmd),
          bot_target: bot_target,
          args: args,
          raw: raw
        }}

      nil ->
        {:error, "Text does not start with a bot command"}
    end
  end

  def handler(%{"text" => text} = params, agent) do
    handler(%{text: text} |> Map.merge(Map.drop(params, ["text"])), agent)
  end

  defp parse_captures([cmd]), do: {cmd, nil, ""}
  defp parse_captures([cmd, bot | []]), do: {cmd, normalize_bot(bot), ""}
  defp parse_captures([cmd, bot, rest | _]), do: {cmd, normalize_bot(bot), rest || ""}

  defp normalize_bot(""), do: nil
  defp normalize_bot(nil), do: nil
  defp normalize_bot(bot), do: bot

  defp parse_args(""), do: []
  defp parse_args(nil), do: []
  defp parse_args(rest) do
    rest
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
  end
end
