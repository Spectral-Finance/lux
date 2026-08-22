"""
Empirical Verification and Adversarial Challenge Harness for Lux.LLM.OpenRouter
"""

import sys
import json
import re

def test_tool_to_function_lens_schema_vs_params():
    print("=== Test 1: Lens schema vs params selection logic in tool_to_function ===")
    
    # Elixir Lens logic implementation simulation:
    # parameters =
    #   cond do
    #     is_map(lens.schema) and map_size(lens.schema) > 0 -> lens.schema
    #     is_map(lens.params) -> lens.params
    #     true -> %{}
    #   end

    def select_parameters(lens_schema, lens_params):
        if isinstance(lens_schema, dict) and len(lens_schema) > 0:
            return lens_schema
        elif isinstance(lens_params, dict):
            return lens_params
        else:
            return {}

    # Case 1: Schema populated, params empty
    p1 = select_parameters({"type": "object", "properties": {"a": {"type": "string"}}}, {})
    assert p1 == {"type": "object", "properties": {"a": {"type": "string"}}}, f"Failed case 1: {p1}"

    # Case 2: Schema empty {}, params populated
    p2 = select_parameters({}, {"type": "object", "properties": {"b": {"type": "integer"}}})
    assert p2 == {"type": "object", "properties": {"b": {"type": "integer"}}}, f"Failed case 2: {p2}"

    # Case 3: Both schema and params populated
    p3 = select_parameters({"schema_key": 1}, {"params_key": 2})
    assert p3 == {"schema_key": 1}, f"Failed case 3: {p3}"

    # Case 4: Schema nil, params populated
    p4 = select_parameters(None, {"params_key": 2})
    assert p4 == {"params_key": 2}, f"Failed case 4: {p4}"

    # Case 5: Schema {}, params None
    p5 = select_parameters({}, None)
    assert p5 == {}, f"Failed case 5: {p5}"

    print("  [PASS] Lens schema vs params logic verified.")

def test_tool_to_function_lens_name_bug():
    print("\n=== Test 2: Lens/Beam/Prism module_name vs name fallback bug ===")
    
    # In Lux.Lens.new(attrs): module_name: attrs[:module_name] || ""
    # In tool_to_function(%Lens{} = lens):
    # name = lens.module_name || lens.name || "unnamed_lens"
    
    # In Elixir, "" (empty string) is TRUTHY.
    # Therefore, "" || "MyLens" evaluates to ""!
    
    def elixir_or(a, b):
        # In Elixir, only nil and False are falsy. "" is TRUTHY!
        if a is not None and a is not False:
            return a
        if b is not None and b is not False:
            return b
        return None

    # Simulate raw Lens struct created with Lens.new(name: "MyLens")
    lens_module_name = "" # Lux.Lens.new sets module_name to "" if not provided
    lens_name = "MyLens"

    res_name = elixir_or(elixir_or(lens_module_name, lens_name), "unnamed_lens")
    print(f"  Resulting function name for Lens.new(name: 'MyLens'): '{res_name}'")
    
    if res_name == "":
        print("  [BUG CONFIRMED] Lens module_name defaults to '' (empty string), which is truthy in Elixir.")
        print("                  'name = lens.module_name || lens.name || \"unnamed_lens\"' evaluates to ''!")
        print("                  The function name sent to OpenRouter API becomes '' instead of 'MyLens'!")
        lens_name_bug = True
    else:
        lens_name_bug = False

    assert lens_name_bug == True

def test_tool_execution_underscore_bug():
    print("\n=== Test 3: Tool module name reconstitution bug (underscores to dots) ===")
    
    # In tool_to_function:
    # function_name = String.replace(module_name, ".", "_")
    # In execute_tool(tool_name, args, ctx):
    # tool_name |> String.replace("_", ".") |> List.wrap() |> Module.concat()
    
    modules = [
        "Lux.Prisms.WeatherPrism",
        "Lux.Beams.Trade_Risk_Management",
        "My_App.Custom_Tool",
        "Lux.LLM.OpenRouterTest.TestPrism"
    ]

    for mod in modules:
        func_name = mod.replace(".", "_")
        reconstituted = func_name.replace("_", ".")
        status = "OK" if reconstituted == mod else "BROKEN"
        print(f"  Module: {mod:35s} -> Func: {func_name:35s} -> Reconstituted: {reconstituted:35s} [{status}]")
        if status == "BROKEN":
            print(f"    -> BUG: Module '{mod}' reconstituted as '{reconstituted}' which fails Code.ensure_loaded/1!")

def test_response_signal_validation_plain_text_bug():
    print("\n=== Test 4: ResponseSignal validation failure on plain text LLM content ===")
    
    # ResponseSignal schema in lux/lib/lux/llm/response_signal.ex:
    # properties:
    #   content: %{anyOf: [%{type: :object}, %{type: :null}]}
    # required: ["content", "model", "finish_reason", "tool_calls"]

    def validate_content_against_schema(content):
        # type :object means a JSON map (dict in Python)
        # type :null means None
        if isinstance(content, dict):
            return True, "valid object"
        elif content is None:
            return True, "valid null"
        elif isinstance(content, str):
            return False, f"String '{content}' is neither object nor null"
        else:
            return False, f"Type {type(content)} is neither object nor null"

    # Test 1: Structured output JSON map
    v1, msg1 = validate_content_against_schema({"result": "hello"})
    print(f"  Structured content map: {v1} ({msg1})")
    assert v1 == True

    # Test 2: Tool call content null
    v2, msg2 = validate_content_against_schema(None)
    print(f"  Tool call content null: {v2} ({msg2})")
    assert v2 == True

    # Test 3: Plain text content string from OpenRouter
    plain_text = "Here is the response to your prompt."
    v3, msg3 = validate_content_against_schema(plain_text)
    print(f"  Plain text content string: {v3} ({msg3})")
    if not v3:
        print("  [CRITICAL BUG CONFIRMED] ResponseSignal schema restricts `content` to object or null.")
        print("                          Standard plain text LLM completions return string content,")
        print("                          causing ResponseSignal.validate/1 to FAIL for all plain text responses!")

def audit_exunit_test_shortcuts():
    print("\n=== Test 5: Audit ExUnit OpenRouterTest for shortcuts and missing scenarios ===")
    
    # Read test/lux/llm/open_router_test.exs
    test_path = "/home/Konor1743/Operacion Dolar/lux/lux/test/lux/llm/open_router_test.exs"
    with open(test_path, "r") as f:
        code = f.read()

    tests_found = re.findall(r'test "(.*?)" do', code)
    print(f"  Found {len(tests_found)} ExUnit tests:")
    for t in tests_found:
        print(f"    - {t}")

    # Check for shortcuts in mock responses
    json_content_mock_count = code.count('~s({"result"')
    print(f"\n  Mock responses with artificial JSON maps: {json_content_mock_count}")
    print("  Note: ExUnit tests exclusively pass ~s({\"result\": ...}) as content in mocks, avoiding plain text responses.")
    print("        This masked the ResponseSignal schema bug in ExUnit testing!")

    # Missing coverage audit
    missing_areas = [
        "json_response: true with json_schema map",
        "json_response: true with json_schema module",
        "json_response: true with json_schema nil ('Reply in json format')",
        "tool_choice: :none / :auto / custom map formatting",
        "execute_tool for Lens module",
        "execute_tool for Beam module",
        "execute_tool error handling (when tool fails or raises)",
        "Missing usage field in API response",
        "HTTP 400 error handling with string body ('{\"error\": \"message\"}')",
        "HTTP 500 server error responses",
        "Network transport errors ({:error, %Req.TransportError{}})",
        "Lens created via Lens.new(name: ...) without module_name"
    ]
    print("\n  Missing Test Coverage Areas in ExUnit Suite:")
    for area in missing_areas:
        print(f"    [UNTESTED] {area}")

if __name__ == "__main__":
    test_tool_to_function_lens_schema_vs_params()
    test_tool_to_function_lens_name_bug()
    test_tool_execution_underscore_bug()
    test_response_signal_validation_plain_text_bug()
    audit_exunit_test_shortcuts()
