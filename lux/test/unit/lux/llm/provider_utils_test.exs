defmodule Lux.LLM.ProviderUtilsTest do
  use UnitCase, async: true

  alias Lux.LLM.ProviderUtils

  require Lux.Beam
  require Lux.Lens
  require Lux.Prism

  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism,
      name: "Test Prism",
      input_schema: %{type: :object, properties: %{value: %{type: :string}}},
      description: "A test prism"

    def handler(%{"value" => "success"}, _context), do: {:ok, %{result: "success"}}
    def handler(%{"value" => "failure"}, _context), do: {:error, "failure test"}
  end

  defmodule TestBeam do
    @moduledoc false
    use Lux.Beam,
      name: "Test Beam",
      input_schema: %{type: :object, properties: %{value: %{type: :string}}},
      description: "A test beam"

    sequence do
      step(:test, TestPrism, %{})
    end
  end

  defmodule TestLens do
    @moduledoc false
    use Lux.Lens,
      name: "TestLens",
      description: "Gets test data",
      schema: %{
        type: "object",
        properties: %{
          query: %{type: "string", description: "Query string"}
        }
      }
  end

  # ─── Tool Conversion Tests ───────────────────────────────────────────────

  describe "tool_to_openai_function/1" do
    test "converts a Prism to OpenAI function format" do
      prism = TestPrism.view()
      result = ProviderUtils.tool_to_openai_function(prism)

      assert %{
               type: "function",
               function: %{
                 name: name,
                 description: "A test prism",
                 parameters: %{type: :object}
               }
             } = result

      # Name should have dots replaced with underscores
      refute String.contains?(name, ".")
    end

    test "converts a Beam to OpenAI function format" do
      beam = TestBeam.view()
      result = ProviderUtils.tool_to_openai_function(beam)

      assert %{
               type: "function",
               function: %{
                 description: "A test beam",
                 parameters: %{type: :object}
               }
             } = result
    end

    test "converts a Lens to OpenAI function format" do
      lens = TestLens.view()
      result = ProviderUtils.tool_to_openai_function(lens)

      assert %{
               type: "function",
               function: %{
                 description: "Gets test data",
                 parameters: %{type: "object"}
               }
             } = result
    end

    test "converts module atoms" do
      result = ProviderUtils.tool_to_openai_function(TestPrism)

      assert %{type: "function", function: %{description: "A test prism"}} = result
    end
  end

  describe "tool_to_anthropic_function/1" do
    test "converts a Prism to Anthropic format (no type wrapper)" do
      prism = TestPrism.view()
      result = ProviderUtils.tool_to_anthropic_function(prism)

      assert %{
               name: _,
               description: "A test prism",
               input_schema: %{type: :object}
             } = result

      # Should NOT have the `type: "function"` wrapper
      refute Map.has_key?(result, :type)
    end
  end

  # ─── Content Parsing Tests ──────────────────────────────────────────────

  describe "parse_json_content/2" do
    test "parses valid JSON" do
      assert {:ok, %{"key" => "value"}} =
               ProviderUtils.parse_json_content(~s({"key": "value"}), [])
    end

    test "returns error for invalid JSON in strict mode" do
      assert {:error, _} = ProviderUtils.parse_json_content("not json", strict: true)
    end

    test "returns raw string for invalid JSON in lenient mode" do
      assert {:ok, "not json"} = ProviderUtils.parse_json_content("not json", strict: false)
    end

    test "handles nil" do
      assert {:ok, nil} = ProviderUtils.parse_json_content(nil)
    end
  end

  describe "parse_content_lenient/1" do
    test "parses valid JSON" do
      assert {:ok, %{"a" => 1}} = ProviderUtils.parse_content_lenient(~s({"a": 1}))
    end

    test "returns raw string for non-JSON" do
      assert {:ok, "hello world"} = ProviderUtils.parse_content_lenient("hello world")
    end

    test "handles nil" do
      assert {:ok, nil} = ProviderUtils.parse_content_lenient(nil)
    end
  end

  # ─── Message Building Tests ─────────────────────────────────────────────

  describe "build_user_messages/1" do
    test "wraps prompt in user message" do
      assert [%{role: "user", content: "hello"}] = ProviderUtils.build_user_messages("hello")
    end
  end

  describe "build_tools_config/2" do
    test "returns empty list for empty tools" do
      assert [] = ProviderUtils.build_tools_config([])
    end

    test "converts tools to OpenAI format by default" do
      tools = [TestPrism.view()]
      result = ProviderUtils.build_tools_config(tools, :openai)
      assert [%{type: "function"}] = result
    end

    test "converts tools to Anthropic format" do
      tools = [TestPrism.view()]
      result = ProviderUtils.build_tools_config(tools, :anthropic)
      assert [%{name: _, description: _, input_schema: _}] = result
    end
  end

  # ─── Tool Choice Formatting Tests ───────────────────────────────────────

  describe "format_tool_choice/1" do
    test "formats :none" do
      assert "none" = ProviderUtils.format_tool_choice(:none)
    end

    test "formats :auto" do
      assert "auto" = ProviderUtils.format_tool_choice(:auto)
    end

    test "formats string name" do
      assert %{"type" => "function", "function" => %{"name" => "My_Tool"}} =
               ProviderUtils.format_tool_choice("My.Tool")
    end

    test "defaults to auto for unknown" do
      assert "auto" = ProviderUtils.format_tool_choice(nil)
    end
  end

  # ─── Sanitize Function Name Tests ───────────────────────────────────────

  describe "sanitize_function_name/1" do
    test "replaces dots with underscores" do
      assert "Elixir_MyModule_SubModule" = ProviderUtils.sanitize_function_name("Elixir.MyModule.SubModule")
    end

    test "leaves clean names unchanged" do
      assert "my_function" = ProviderUtils.sanitize_function_name("my_function")
    end
  end

  # ─── Tool Execution Tests ──────────────────────────────────────────────

  describe "execute_tool_calls/1" do
    test "handles nil" do
      assert {:ok, nil} = ProviderUtils.execute_tool_calls(nil)
    end

    test "executes prism tool calls" do
      tool_calls = [
        %{
          "function" => %{
            "name" => "#{TestPrism}",
            "arguments" => ~s({"value": "success"})
          }
        }
      ]

      assert {:ok, [%{result: "success"}]} = ProviderUtils.execute_tool_calls(tool_calls)
    end
  end
end
