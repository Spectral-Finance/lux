defmodule Lux.Prisms.Telegram.Formatter do
  @moduledoc """
  Utilities for formatting messages for Telegram's specific requirements.
  """

  @markdown_v2_escapes ~w(\\ _ * [ ] ( ) ~ ` > # + - = | { } . !)

  @doc """
  Escapes text for Telegram MarkdownV2.
  """
  def escape_markdown_v2(text) when is_binary(text) do
    Enum.reduce(@markdown_v2_escapes, text, fn char, acc ->
      String.replace(acc, char, "\\" <> char)
    end)
  end

  @doc """
  Wraps text in MarkdownV2 bold.
  """
  def bold(text, :markdown), do: "*#{escape_markdown_v2(text)}*"
  def bold(text, :html), do: "<b>#{text}</b>"

  @doc """
  Wraps text in MarkdownV2 code blocks.
  """
  def code(text, lang \\ "") do
    "```#{lang}\n#{text}\n```"
  end
end
