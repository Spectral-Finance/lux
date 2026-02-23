defmodule Lux.Prisms.Telegram.Messages.FormatTextTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Messages.FormatText

  @agent_ctx %{name: "TestAgent"}

  describe "handler/2 — format conversion" do
    test "converts Markdown bold to HTML" do
      assert {:ok, %{formatted: "<b>bold</b>", parse_mode: "HTML"}} =
               FormatText.handler(%{text: "*bold*", from: "Markdown", to: "HTML"}, @agent_ctx)
    end

    test "converts Markdown italic to HTML" do
      assert {:ok, %{formatted: "<i>italic</i>", parse_mode: "HTML"}} =
               FormatText.handler(%{text: "_italic_", from: "Markdown", to: "HTML"}, @agent_ctx)
    end

    test "converts Markdown code to HTML" do
      assert {:ok, %{formatted: html, parse_mode: "HTML"}} =
               FormatText.handler(%{text: "`code`", from: "Markdown", to: "HTML"}, @agent_ctx)
      assert html == "<code>code</code>"
    end

    test "converts HTML bold to Markdown" do
      assert {:ok, %{formatted: "*Hello*", parse_mode: "Markdown"}} =
               FormatText.handler(%{text: "<b>Hello</b>", from: "HTML", to: "Markdown"}, @agent_ctx)
    end

    test "converts HTML italic to Markdown" do
      assert {:ok, %{formatted: "_World_", parse_mode: "Markdown"}} =
               FormatText.handler(%{text: "<i>World</i>", from: "HTML", to: "Markdown"}, @agent_ctx)
    end

    test "converts HTML code to Markdown" do
      assert {:ok, %{formatted: "`snippet`", parse_mode: "Markdown"}} =
               FormatText.handler(%{text: "<code>snippet</code>", from: "HTML", to: "Markdown"}, @agent_ctx)
    end

    test "returns same text when format matches" do
      assert {:ok, %{formatted: "hello", parse_mode: "HTML"}} =
               FormatText.handler(%{text: "hello", from: "HTML", to: "HTML"}, @agent_ctx)
    end

    test "handles plain text passthrough" do
      assert {:ok, %{formatted: "just text", parse_mode: "HTML"}} =
               FormatText.handler(%{text: "just text", from: "plain", to: "HTML"}, @agent_ctx)
    end

    test "strips HTML tags when converting to Markdown" do
      assert {:ok, %{formatted: formatted, parse_mode: "Markdown"}} =
               FormatText.handler(%{text: "<b>bold</b> plain", from: "HTML", to: "Markdown"}, @agent_ctx)
      assert formatted =~ "*bold*"
      assert formatted =~ "plain"
    end

    test "converts Markdown link to HTML" do
      assert {:ok, %{formatted: html, parse_mode: "HTML"}} =
               FormatText.handler(%{text: "[Click](https://example.com)", from: "Markdown", to: "HTML"}, @agent_ctx)
      assert html =~ "href=\"https://example.com\""
      assert html =~ "Click"
    end

    test "accepts string keys in params" do
      assert {:ok, %{formatted: _, parse_mode: "HTML"}} =
               FormatText.handler(%{"text" => "*bold*", "from" => "Markdown", "to" => "HTML"}, @agent_ctx)
    end

    test "converts HTML to MarkdownV2" do
      assert {:ok, %{formatted: formatted, parse_mode: "MarkdownV2"}} =
               FormatText.handler(%{text: "<b>bold</b>", from: "HTML", to: "MarkdownV2"}, @agent_ctx)
      assert formatted =~ "*bold*"
    end
  end
end
