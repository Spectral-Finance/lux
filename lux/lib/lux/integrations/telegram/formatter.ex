defmodule Lux.Integrations.Telegram.Formatter do
  @moduledoc """
  A utility module to escape and format text for Telegram Bot API MarkdownV2 and HTML modes.
  """

  # Special characters in MarkdownV2 that must be escaped
  @markdown_v2_escapes [
    "_", "*", "[", "]", "(", ")", "~", "`", ">", "#", "+", "-", "=", "|", "{", "}", ".", "!"
  ]

  @doc """
  Escapes special characters in text for Telegram's MarkdownV2 parse mode.
  """
  def escape_markdown(text) when is_binary(text) do
    Enum.reduce(@markdown_v2_escapes, text, fn char, acc ->
      String.replace(acc, char, "\\" <> char)
    end)
  end
  def escape_markdown(other), do: other

  @doc """
  Escapes special characters in text for Telegram's HTML parse mode.
  """
  def escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
  def escape_html(other), do: other

  @doc """
  Formats text as bold using HTML or MarkdownV2.
  """
  def bold(text, :html), do: "<b>" <> escape_html(text) <> "</b>"
  def bold(text, :markdown), do: "*" <> escape_markdown(text) <> "*"

  @doc """
  Formats text as italic using HTML or MarkdownV2.
  """
  def italic(text, :html), do: "<i>" <> escape_html(text) <> "</i>"
  def italic(text, :markdown), do: "_" <> escape_markdown(text) <> "_"

  @doc """
  Formats text as inline code using HTML or MarkdownV2.
  """
  def code(text, :html), do: "<code>" <> escape_html(text) <> "</code>"
  def code(text, :markdown), do: "`" <> escape_markdown(text) <> "`"

  @doc """
  Formats text as a hyperlink.
  """
  def link(text, url, :html) do
    "<a href=\"" <> escape_html(url) <> "\">" <> escape_html(text) <> "</a>"
  end
  def link(text, url, :markdown) do
    "[" <> escape_markdown(text) <> "](" <> escape_url(url) <> ")"
  end

  defp escape_url(url) when is_binary(url) do
    url
    |> String.replace("\\", "\\\\")
    |> String.replace(")", "\\)")
  end
  defp escape_url(other), do: other
end
