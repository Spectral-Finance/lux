defmodule Lux.Integrations.Telegram.MessageProcessing.CommandParser do
  @moduledoc """
  Robust command parser for Telegram bot messages.
  Supports bot username tagging (@BotName), quoted arguments, positional parameters,
  and GNU-style options/flags (--flag=value, -f value, --bool-flag).
  """

  @default_prefix "/"

  @doc """
  Determines if a given text is a bot command.
  """
  @spec is_command?(String.t(), String.t()) :: boolean()
  def is_command?(nil, _), do: false

  def is_command?(text, prefix \\ @default_prefix) when is_binary(text) do
    String.starts_with?(String.trim_leading(text), prefix)
  end

  @doc """
  Parses a command string into a structured command map.

  ## Options
    - `:bot_username` - The username of this bot. If set and the command contains
      `@other_bot`, the parser returns `{:ignored, target_bot}`.
    - `:prefix` - Command prefix character, defaults to `"/"`.
  """
  @spec parse(String.t(), keyword()) :: {:ok, map()} | {:ignored, String.t()} | {:error, term()}
  def parse(text, opts \\ [])

  def parse(nil, _opts), do: {:ok, %{is_command: false, raw_text: ""}}

  def parse(text, opts) when is_binary(text) do
    prefix = Keyword.get(opts, :prefix, @default_prefix)
    bot_username = Keyword.get(opts, :bot_username)
    trimmed = String.trim(text)

    if not String.starts_with?(trimmed, prefix) do
      {:ok, %{is_command: false, raw_text: text}}
    else
      # Strip leading prefix
      without_prefix = String.slice(trimmed, String.length(prefix)..-1//1)

      # Split command token and argument string
      {cmd_token, raw_args} =
        case String.split(without_prefix, ~r/\s+/, parts: 2) do
          [cmd] -> {cmd, ""}
          [cmd, args] -> {cmd, String.trim(args)}
        end

      # Parse command and optional @bot_username
      {cmd_name, target_bot} = parse_command_token(cmd_token)

      if bot_username && target_bot &&
           String.downcase(bot_username) != String.downcase(target_bot) do
        {:ignored, target_bot}
      else
        tokens = tokenize(raw_args)
        {args, options} = extract_args_and_options(tokens)

        {:ok,
         %{
           is_command: true,
           command: String.downcase(cmd_name),
           original_command: cmd_name,
           target_bot: target_bot,
           args: args,
           options: options,
           raw_args: raw_args,
           raw_text: text
         }}
      end
    end
  rescue
    e -> {:error, "Failed to parse command: #{Exception.message(e)}"}
  end

  @doc """
  Extracts just the command name without prefix or bot mention.
  """
  @spec extract_command_name(String.t(), String.t()) :: String.t() | nil
  def extract_command_name(text, prefix \\ @default_prefix) do
    case parse(text, prefix: prefix) do
      {:ok, %{is_command: true, command: cmd}} -> cmd
      _ -> nil
    end
  end

  @doc """
  Validates parsed command against a specification map.

  Example spec:
    %{
      required_args: [:coin],
      optional_args: [:target_currency],
      allowed_options: [:verbose, :network]
    }
  """
  @spec validate_spec(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def validate_spec(%{is_command: true, args: args, options: options} = parsed, spec) do
    required = Map.get(spec, :required_args, [])
    min_args = length(required)

    if length(args) < min_args do
      {:error, "Missing required argument: #{Enum.at(required, length(args))}"}
    else
      {:ok, parsed}
    end
  end

  def validate_spec(_, _), do: {:error, "Not a valid command"}

  # --- Internal Helpers ---

  defp parse_command_token(token) do
    case String.split(token, "@", parts: 2) do
      [name] -> {name, nil}
      [name, bot] -> {name, bot}
    end
  end

  # Tokenizes string respecting double and single quotes and escaped quotes
  defp tokenize(args_str) when is_binary(args_str) do
    regex = ~r/"([^"\\]*(?:\\.[^"\\]*)*)"|'([^'\\]*(?:\\.[^'\\]*)*)'|(\S+)/

    Regex.scan(regex, args_str)
    |> Enum.map(fn
      [_, double_quoted] when double_quoted != "" ->
        unescape(double_quoted)

      [_, _, single_quoted] when single_quoted != "" ->
        unescape(single_quoted)

      [_, _, _, bare_token] ->
        bare_token

      [full_match | _] ->
        full_match
    end)
  end

  defp unescape(str) do
    str
    |> String.replace("\\\"", "\"")
    |> String.replace("\\'", "'")
    |> String.replace("\\\\", "\\")
  end

  # Separates tokens into positional arguments and options/flags
  defp extract_args_and_options(tokens) do
    do_extract(tokens, [], %{})
  end

  defp do_extract([], args_acc, opts_acc) do
    {Enum.reverse(args_acc), opts_acc}
  end

  defp do_extract([token | rest], args_acc, opts_acc) do
    cond do
      # Long option with value: --key=value
      String.starts_with?(token, "--") and String.contains?(token, "=") ->
        [key, val] = String.split(String.slice(token, 2..-1//1), "=", parts: 2)
        opt_key = String.to_atom(String.replace(key, "-", "_"))
        do_extract(rest, args_acc, Map.put(opts_acc, opt_key, coerce_value(val)))

      # Long boolean flag or followed by value: --flag
      String.starts_with?(token, "--") ->
        key = String.slice(token, 2..-1//1)
        opt_key = String.to_atom(String.replace(key, "-", "_"))

        case rest do
          [next_val | following] when not (String.starts_with?(next_val, "-")) ->
            do_extract(following, args_acc, Map.put(opts_acc, opt_key, coerce_value(next_val)))

          _ ->
            do_extract(rest, args_acc, Map.put(opts_acc, opt_key, true))
        end

      # Short option: -k value or -v
      String.starts_with?(token, "-") and String.length(token) == 2 ->
        key = String.slice(token, 1..1)
        opt_key = String.to_atom(key)

        case rest do
          [next_val | following] when not (String.starts_with?(next_val, "-")) ->
            do_extract(following, args_acc, Map.put(opts_acc, opt_key, coerce_value(next_val)))

          _ ->
            do_extract(rest, args_acc, Map.put(opts_acc, opt_key, true))
        end

      # Positional argument
      true ->
        do_extract(rest, [coerce_value(token) | args_acc], opts_acc)
    end
  end

  defp coerce_value(str) when is_binary(str) do
    cond do
      str in ["true", "TRUE", "yes", "YES"] ->
        true

      str in ["false", "FALSE", "no", "NO"] ->
        false

      match?({_, ""}, Integer.parse(str)) ->
        {int, ""} = Integer.parse(str)
        int

      match?({_, ""}, Float.parse(str)) ->
        {flt, ""} = Float.parse(str)
        flt

      true ->
        str
    end
  end

  defp coerce_value(other), do: other
end
