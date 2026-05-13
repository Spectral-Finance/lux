defmodule Lux.Prisms.Telegram.Processing.ParseCommand do
  @moduledoc """
  Parses Telegram slash commands into routing data for agents.

  The prism accepts raw Telegram message text and extracts the command name,
  optional bot username, positional arguments, key/value parameters, mentions,
  and `/start` deep-link payloads.
  """

  use Lux.Prism,
    name: "Parse Telegram Command",
    description: "Parses Telegram slash commands, arguments, parameters, mentions, and deep-link payloads",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "Incoming Telegram message text that starts with a slash command"
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        command: %{type: :string, description: "Command name without the leading slash"},
        bot_username: %{type: :string, description: "Optional bot username mentioned after the command"},
        arguments: %{type: :string, description: "Raw argument text after the command"},
        tokens: %{type: :array, description: "Shell-like argument tokens"},
        params: %{type: :object, description: "Extracted key/value or flag parameters"},
        mentions: %{type: :array, description: "Telegram @mentions found in arguments"},
        deep_link_payload: %{type: :string, description: "Payload attached to /start deep links"}
      },
      required: ["command", "arguments", "tokens", "params", "mentions"]
    }

  @command_re ~r/^\/(?<command>[A-Za-z0-9_]+)(?:@(?<bot>[A-Za-z0-9_]+))?(?:\s+(?<args>.*))?$/s
  @token_re ~r/"([^"]*)"|'([^']*)'|(\S+)/
  @mention_re ~r/^@[A-Za-z0-9_]{2,}$/

  @doc """
  Handles command parsing for use as a prism.
  """
  def handler(params, _agent) when is_map(params) do
    params
    |> value(:text)
    |> parse()
  end

  def handler(_params, _agent), do: {:error, "Missing or invalid text"}

  @doc """
  Parses a Telegram command string.
  """
  def parse(text) when is_binary(text) do
    text = String.trim(text)

    case Regex.named_captures(@command_re, text) do
      %{"command" => command, "bot" => bot_username, "args" => arguments} ->
        tokens = tokenize(arguments || "")
        params = params_from_tokens(tokens)
        mentions = mentions_from_tokens(tokens)

        {:ok,
         %{
           command: command,
           bot_username: blank_to_nil(bot_username),
           arguments: arguments || "",
           tokens: tokens,
           params: params,
           mentions: mentions,
           deep_link_payload: deep_link_payload(command, tokens)
         }}

      _ ->
        {:error, "Text does not contain a Telegram command"}
    end
  end

  def parse(_text), do: {:error, "Missing or invalid text"}

  defp tokenize(""), do: []

  defp tokenize(arguments) do
    @token_re
    |> Regex.scan(arguments)
    |> Enum.map(fn captures ->
      captures
      |> Enum.drop(1)
      |> Enum.find_value("", fn value -> if value == "", do: nil, else: value end)
    end)
  end

  defp params_from_tokens(tokens) do
    Enum.reduce(tokens, %{}, fn token, params ->
      cond do
        String.starts_with?(token, "--") and String.contains?(token, "=") ->
          [key, value] = token |> String.trim_leading("--") |> String.split("=", parts: 2)
          Map.put(params, key, value)

        String.starts_with?(token, "--") ->
          token
          |> String.trim_leading("--")
          |> then(&Map.put(params, &1, true))

        String.contains?(token, "=") ->
          [key, value] = String.split(token, "=", parts: 2)
          Map.put(params, key, value)

        true ->
          params
      end
    end)
  end

  defp mentions_from_tokens(tokens) do
    Enum.filter(tokens, &Regex.match?(@mention_re, &1))
  end

  defp deep_link_payload("start", [payload | _]), do: payload
  defp deep_link_payload(_command, _tokens), do: nil

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp value(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
