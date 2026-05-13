defmodule Lux.Prisms.Telegram.Processing.FormatMessageTest do
  use UnitCase, async: true

  alias Lux.Prisms.Telegram.Processing.FormatMessage

  describe "handler/2" do
    test "formats entities as HTML and escapes unsafe text" do
      assert {:ok, result} =
               FormatMessage.handler(
                 %{
                   text: "Hello <Lux> docs",
                   target_format: "HTML",
                   entities: [
                     %{offset: 6, length: 5, type: "bold"},
                     %{offset: 12, length: 4, type: "text_link", url: "https://example.com?a=1&b=2"}
                   ]
                 },
                 nil
               )

      assert result.text ==
               ~s(Hello <b>&lt;Lux&gt;</b> <a href="https://example.com?a=1&amp;b=2">docs</a>)

      assert result.parse_mode == "HTML"
      assert result.target_format == "HTML"
    end

    test "formats entities as MarkdownV2 and escapes reserved characters" do
      assert {:ok, result} =
               FormatMessage.handler(
                 %{
                   text: "Hello Lux!",
                   target_format: "MarkdownV2",
                   entities: [%{"offset" => 6, "length" => 3, "type" => "italic"}]
                 },
                 nil
               )

      assert result.text == "Hello _Lux_\\!"
      assert result.parse_mode == "MarkdownV2"
    end

    test "returns plain text by default" do
      assert {:ok, %{text: "Hello *Lux*", parse_mode: nil, target_format: "plain"}} =
               FormatMessage.handler(%{text: "Hello *Lux*"}, nil)
    end

    test "validates text and target format" do
      assert {:error, "Missing or invalid text"} = FormatMessage.handler(%{}, nil)

      assert {:error, "Unsupported target_format"} =
               FormatMessage.handler(%{text: "Hello", target_format: "RTF"}, nil)
    end
  end

  describe "schema validation" do
    test "declares input and output schemas" do
      prism = FormatMessage.view()

      assert prism.input_schema.required == ["text"]
      assert Map.has_key?(prism.input_schema.properties, :entities)
      assert prism.output_schema.required == ["text", "target_format"]
      assert Map.has_key?(prism.output_schema.properties, :parse_mode)
    end
  end
end
