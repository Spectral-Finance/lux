defmodule Lux.Prisms.Telegram.FormatMessageTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Telegram.FormatMessage

  test "formats bold HTML" do
    assert {:ok, %{"formatted_text" => "<b>hello</b>"}} = FormatMessage.run(%{"text" => "hello", "mode" => "html", "style" => "bold"})
  end

  test "formats italic Markdown" do
    assert {:ok, %{"formatted_text" => "_hello_"}} = FormatMessage.run(%{"text" => "hello", "mode" => "markdown", "style" => "italic"})
  end

  test "escapes Markdown" do
    assert {:ok, %{"formatted_text" => "\\!hello\\."}} = FormatMessage.run(%{"text" => "!hello.", "mode" => "markdown", "style" => "escape"})
  end

  test "formats link Markdown" do
    assert {:ok, %{"formatted_text" => "[Lux](https://lux.io)"}} = FormatMessage.run(%{"text" => "Lux", "mode" => "markdown", "style" => "link", "url" => "https://lux.io"})
  end
end
