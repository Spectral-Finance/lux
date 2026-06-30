defmodule Lux.Integrations.Telegram.CommandParser do
  @moduledoc """
  A utility module to parse commands and extract arguments from Telegram messages.
  Supports basic commands, deep links (from `/start <payload>`), and options/flags.
  """

  @doc """
  Parses a command from message text.

  ## Examples
      iex> parse("/start hello_world")
      {:ok, %{command: "start", args: ["hello_world"], raw_args: "hello_world", flags: %{}}}

      iex> parse("/add --item apples --qty 5")
      {:ok, %{command: "add", args: [], raw_args: "--item apples --qty 5", flags: %{"item" => "apples", "qty" => "5"}}}

      iex> parse("Not a command")
      {:error, :not_a_command}
  """
  def parse(text) when is_binary(text) do
    trimmed = String.trim(text)

    if String.starts_with?(trimmed, "/") do
      # Extract command and arguments
      [raw_cmd | rest] = String.split(trimmed, ~r/\s+/, parts: 2)
      
      # Strip leading slash and potential bot username suffix (e.g. /start@MyBot -> start)
      command = 
        raw_cmd 
        |> String.slice(1..-1//1) 
        |> String.split("@") 
        |> List.first()

      raw_args = List.first(rest) || ""
      
      # Handle quoted args using OptionParser.split/1
      tokens = OptionParser.split(raw_args)

      {flags, args} = parse_tokens(tokens, %{}, [])

      {:ok, %{
        command: command,
        args: args,
        raw_args: raw_args,
        flags: flags
      }}
    else
      {:error, :not_a_command}
    end
  end

  def parse(_), do: {:error, :not_a_command}

  @doc """
  Extracts deep link payload from a start command.
  If text is `/start payload`, returns `{:ok, "payload"}`.
  """
  def extract_deep_link(text) do
    case parse(text) do
      {:ok, %{command: "start", args: [payload | _]}} -> {:ok, payload}
      _ -> {:error, :no_deep_link}
    end
  end

  defp parse_tokens([], flags, positional), do: {flags, Enum.reverse(positional)}

  defp parse_tokens([flag | rest], flags, positional) when String.starts_with?(flag, "-") do
    cond do
      flag == "-" ->
        parse_tokens(rest, flags, [flag | positional])

      flag == "--" ->
        # Treat all remaining tokens as positional arguments
        {flags, Enum.reverse(positional) ++ rest}

      String.contains?(flag, "=") ->
        [k, v] = String.split(flag, "=", parts: 2)
        key = String.replace(k, ~r/^-+/, "")
        parse_tokens(rest, Map.put(flags, key, v), positional)

      true ->
        case rest do
          [next | tail] when not String.starts_with?(next, "-") ->
            key = String.replace(flag, ~r/^-+/, "")
            parse_tokens(tail, Map.put(flags, key, next), positional)

          _ ->
            key = String.replace(flag, ~r/^-+/, "")
            parse_tokens(rest, Map.put(flags, key, "true"), positional)
        end
    end
  end

  defp parse_tokens([arg | rest], flags, positional) do
    parse_tokens(rest, flags, [arg | positional])
  end
end
