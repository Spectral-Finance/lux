defmodule Lux.Prisms.Telegram.Processing.FormatConverterTest do
  use ExUnit.Case, async: true
  
  alias Lux.Prisms.Telegram.Processing.FormatConverter

  describe "handler/2" do
    test "formats text as markdown" do
      params = %{
        text: "Hello world",
        format: "markdown",
        entities: [
          %{type: "bold", offset: 0, length: 5},
          %{type: "italic", offset: 6, length: 5}
        ]
      }
      
      assert {:ok, %{formatted_text: "**Hello** _world_"}} = FormatConverter.handler(params, %{})
    end
    
    test "formats text as html" do
      params = %{
        text: "Hello world",
        format: "html",
        entities: [
          %{type: "bold", offset: 0, length: 5},
          %{type: "italic", offset: 6, length: 5}
        ]
      }
      
      assert {:ok, %{formatted_text: "<b>Hello</b> <i>world</i>"}} = FormatConverter.handler(params, %{})
    end
    
    test "handles missing entities" do
      params = %{
        text: "Hello world",
        format: "markdown"
      }
      
      # Will escape the ' ' space? Wait, space is not escaped.
      assert {:ok, %{formatted_text: "Hello world"}} = FormatConverter.handler(params, %{})
    end
    
    test "handles text with emoji using correct utf16 offsets" do
      params = %{
        text: "Hi 🚀 test",
        format: "html",
        entities: [
          %{type: "bold", offset: 6, length: 4}
        ]
      }
      
      assert {:ok, %{formatted_text: "Hi 🚀 <b>test</b>"}} = FormatConverter.handler(params, %{})
    end
    
    test "handles nested and overlapping entities" do
      params = %{
        text: "abcdef",
        format: "html",
        entities: [
          %{type: "bold", offset: 0, length: 6},
          %{type: "italic", offset: 2, length: 2}
        ]
      }
      assert {:ok, %{formatted_text: "<b>ab<i>cd</i>ef</b>"}} = FormatConverter.handler(params, %{})

      params_overlap = %{
        text: "abcdef",
        format: "html",
        entities: [
          %{type: "bold", offset: 0, length: 4},
          %{type: "italic", offset: 2, length: 4}
        ]
      }
      # Our chunking logic will output <b>ab<i>cd</i></b><i>ef</i>
      assert {:ok, %{formatted_text: "<b>ab<i>cd</i></b><i>ef</i>"}} = FormatConverter.handler(params_overlap, %{})
    end

    test "handles invalid ranges (out of bounds, negative)" do
      params = %{
        text: "abc",
        format: "html",
        entities: [
          %{type: "bold", offset: 1, length: 10},
          %{type: "italic", offset: -1, length: 2},
          %{type: "code", offset: 5, length: 2}
        ]
      }
      # offset: 1, len: 10 gets clamped to offset: 1, len: 2. "b" is code unit 1, "c" is 2.
      # offset: -1 is ignored. offset: 5 is ignored.
      assert {:ok, %{formatted_text: "a<b>bc</b>"}} = FormatConverter.handler(params, %{})
    end

    test "handles escaping markdown and html" do
      params_md = %{
        text: "Hello *world* [link](!)",
        format: "markdownv2",
        entities: [
          %{type: "bold", offset: 0, length: 5}
        ]
      }
      # "Hello" is bold. The rest is escaped.
      # * -> \*
      # [ -> \[
      # ] -> \]
      # ( -> \(
      # ! -> \!
      # ) -> \)
      assert {:ok, %{formatted_text: "*Hello* \\*world\\* \\\[link\\\]\\(\\!\\)"}} = FormatConverter.handler(params_md, %{})
      
      params_html = %{
        text: "<script> & test",
        format: "html",
        entities: []
      }
      assert {:ok, %{formatted_text: "&lt;script&gt; &amp; test"}} = FormatConverter.handler(params_html, %{})
    end

    test "handles missing text or format" do
      assert {:error, _} = FormatConverter.handler(%{text: "hi"}, %{})
      assert {:error, _} = FormatConverter.handler(%{format: "html"}, %{})
    end
  end
end
