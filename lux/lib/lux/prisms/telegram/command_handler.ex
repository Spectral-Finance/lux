defmodule Lux.Prisms.Telegram.CommandHandler do
  @moduledoc """
  Handles extraction of commands and deep-linking parameters.
  """

  @doc """
  Parses a string for commands. Example: "/start payload" -> {:ok, "start", ["payload"]}
  """
  def parse_command(text) when is_binary(text) do
    case Regex.run(~r/^\/([a-zA-Z0-9_]+)(?:\s+(.*))?$/, text) do
      [_, command, params] ->
        args = if params, do: String.split(params, " "), else: []
        {:ok, command, args}
      [_, command] ->
        {:ok, command, []}
      _ ->
        :error
    end
  end

  @doc """
  Extracts deep linking parameters from the /start command.
  """
  def extract_deep_link(text) do
    case parse_command(text) do
      {:ok, "start", [param | _]} -> {:ok, param}
      _ -> :error
    end
  end
end
