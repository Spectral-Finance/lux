defmodule Lux.Prisms.Telegram.CommandRouter do
  @moduledoc """
  Parses bot commands from Telegram messages and routes them with extracted parameters.

  Supports:
  - `/command` — simple commands
  - `/command@botname` — bot-specific commands
  - `/command arg1 arg2` — commands with positional args
  - `/command key=value` — commands with named params
  - Deep links: `/start payload` with base64 decoding
  """

  use Lux.Prism,
    name: "Telegram Command Router",
    description: "Parse bot commands, extract parameters, and route to handlers",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Message text"},
        bot_username: %{type: :string, description: "Bot username for filtering"}
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        command: %{type: :string},
        args: %{type: :array},
        params: %{type: :object}
      }
    }

  @impl true
  def handler(params, _agent) do
    text = params["text"] || params[:text] || ""
    bot_username = params["bot_username"] || params[:bot_username]

    case parse_command(text, bot_username) do
      {:ok, result} -> {:ok, result}
      :not_a_command -> {:ok, %{command: nil, args: [], params: %{}, is_command: false}}
    end
  end

  @doc "Parse a command string into structured data."
  def parse_command(text, bot_username \\ nil) do
    text = String.trim(text)

    case Regex.run(~r/^\/([a-zA-Z0-9_]+)(?:@(\S+))?(?:\s+(.*))?$/, text) do
      nil ->
        :not_a_command

      captures ->
        command = Enum.at(captures, 1, "")
        bot = Enum.at(captures, 2, "")
        rest = Enum.at(captures, 3, "")

        if bot_username && bot != "" && String.downcase(bot) != String.downcase(bot_username) do
          :not_a_command
        else
          {args, params} = parse_args(rest)
          deep_link = if command == "start" && length(args) == 1, do: decode_deep_link(hd(args)), else: nil

          {:ok, %{
            command: "/" <> command,
            raw_command: command,
            bot: if(bot != "", do: bot, else: nil),
            args: args,
            params: params,
            deep_link: deep_link,
            is_command: true
          }}
        end
    end
  end

  @doc "Parse argument string into positional args and named params."
  def parse_args(""), do: {[], %{}}
  def parse_args(str) do
    parts = String.split(str)

    Enum.reduce(parts, {[], %{}}, fn part, {args, params} ->
      case String.split(part, "=", parts: 2) do
        [key, value] -> {args, Map.put(params, key, value)}
        _ -> {args ++ [part], params}
      end
    end)
  end

  @doc "Decode a deep link payload (base64 or plain)."
  def decode_deep_link(payload) do
    case Base.url_decode64(payload, padding: false) do
      {:ok, decoded} -> %{raw: payload, decoded: decoded}
      :error -> %{raw: payload, decoded: payload}
    end
  end
end
