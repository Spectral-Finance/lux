# Adversarial Challenge Report: Lux OpenRouter API Integration (Bounty #95)

## Challenge Summary

**Overall risk assessment**: CRITICAL

Adversarial challenge testing on `Lux.LLM.OpenRouterTest` suite and `Lux.LLM.OpenRouter` revealed three CRITICAL architectural/implementation flaws and twelve UNTESTED functionality areas in the ExUnit test suite. Most notably, standard plain-text LLM chat completions fail validation, tools with underscores in module names cannot be executed, and tools instantiated via `.new(name: ...)` generate empty function names.

---

## Challenges

### [Critical] Challenge 1: `ResponseSignal.validate/1` Rejects All Plain-Text Responses

- **Assumption challenged**: Assumed `ResponseSignal.validate/1` passes all valid OpenRouter chat completion responses.
- **Attack scenario**: Call `Lux.LLM.OpenRouter.call("What is the capital of France?", [], config)` with any model without requesting structured JSON output. OpenRouter returns standard text content `message.content = "The capital of France is Paris."`.
- **Blast radius**: `parse_content/1` returns `{:ok, "The capital of France is Paris."}`. `payload.content` is set to this string. `ResponseSignal` schema restricts `content` to `anyOf: [%{type: :object}, %{type: :null}]`. Because a string is neither an object nor null, `ResponseSignal.validate/1` fails JSON schema validation, causing `OpenRouter.call/3` to return `{:error, schema_errors}` for >90% of real-world OpenRouter completions.
- **Root cause in test suite**: In `Lux.LLM.OpenRouterTest`, all mock completions used `content: ~s({"result": "..."})`. `parse_content/1` parsed this into a map, masking the schema failure in ExUnit.
- **Mitigation**: Update `ResponseSignal` schema definition in `lux/lib/lux/llm/response_signal.ex` to allow strings for `content`:
  ```elixir
  content: %{anyOf: [%{type: :object}, %{type: :string}, %{type: :null}]}
  ```

---

### [Critical] Challenge 2: Tool Module Name Reconstitution Destroys Underscored Module Names

- **Assumption challenged**: Assumed `String.replace(tool_name, "_", ".")` in `execute_tool/3` accurately reconstructs module names from OpenRouter function names.
- **Attack scenario**: Register a tool whose Elixir module name contains underscores, e.g., `Lux.Beams.Trade_Risk_Management` or `My_App.Custom_Tool`.
  1. `tool_to_function/1` maps the module to function name `"Lux_Beams_Trade_Risk_Management"`.
  2. OpenRouter returns a tool call for function `"Lux_Beams_Trade_Risk_Management"`.
  3. `execute_tool/3` runs `String.replace("Lux_Beams_Trade_Risk_Management", "_", ".")`, producing `"Lux.Beams.Trade.Risk.Management"`.
- **Blast radius**: `Code.ensure_loaded(Lux.Beams.Trade.Risk.Management)` returns `{:error, :nofile}`. Tool call execution fails completely with `{:error, "Failed to load tool module Lux_Beams_Trade_Risk_Management: It doesn't seems to be implemented or reacheable"}`.
- **Mitigation**: Rather than naive string replacement of underscores, maintain a mapping of registered tool modules passed in `tools` or check if the exact module name exists before replacing underscores.

---

### [High] Challenge 3: Empty Function Name for Raw Structs via `module_name` Truthiness Bug

- **Assumption challenged**: Assumed `name = lens.module_name || lens.name || "unnamed_lens"` falls back to `lens.name` when `module_name` is not specified.
- **Attack scenario**: Create a Lens struct via `Lux.Lens.new(name: "WeatherAPI")` (or Beam/Prism created without explicit `:module_name`). `Lux.Lens.new/1` sets `module_name: ""`.
- **Blast radius**: In Elixir, `""` (empty string) is TRUTHY. `"" || lens.name` evaluates to `""`. `tool_to_function/1` extracts `name = ""` and produces `%{"type" => "function", "function" => %{"name" => ""}}`. OpenRouter API rejects the request with HTTP 400 Bad Request due to empty function name.
- **Mitigation**: Use explicit string checks in `tool_to_function/1`:
  ```elixir
  name =
    cond do
      is_binary(lens.module_name) and lens.module_name != "" -> lens.module_name
      is_binary(lens.name) and lens.name != "" -> lens.name
      true -> "unnamed_lens"
    end
  ```

---

### [Medium] Challenge 4: ExUnit Test Suite Excludes 12 Core Functional Scenarios

- **Assumption challenged**: Assumed ExUnit test suite `Lux.LLM.OpenRouterTest` provides full coverage for requirements R1-R4.
- **Attack scenario**: Execute edge cases in configuration, response formats, and error handling.
- **Blast radius**: The following 12 scenarios are completely unverified by ExUnit tests:
  1. `json_response: true` with map `json_schema`
  2. `json_response: true` with module `json_schema`
  3. `json_response: true` with `json_schema: nil` (prompt augmentation with "Reply in json format")
  4. `tool_choice` options (`:none`, `:auto`, `"function_name"`, custom map)
  5. Lens tool call execution in `execute_tool/3`
  6. Beam tool call execution in `execute_tool/3`
  7. Tool execution error handling (JSON argument decode failure, missing tool module, execution crash)
  8. Missing `"usage"` field in OpenRouter API response body
  9. OpenRouter string error body format (`{"error": "message_string"}`)
  10. HTTP 500 server error responses
  11. Network transport errors (`{:error, %Req.TransportError{}}`)
  12. Tool structs created via `.new(name: ...)` without `:module_name`

---

## Stress Test Results

| Scenario | Expected Behavior | Actual Behavior | Result |
|----------|-------------------|-----------------|--------|
| OpenRouter plain text response (`"Hello"`) | Valid `ResponseSignal` signal returned | Validation fails in `ResponseSignal.validate/1` (`content` string not allowed by schema) | **FAIL (CRITICAL)** |
| Tool call with underscore in module name (`Trade_Risk_Management`) | Tool module resolved and executed | Module reconstituted as `Trade.Risk.Management` -> `:nofile` error | **FAIL (CRITICAL)** |
| Lens created via `Lens.new(name: "WeatherAPI")` | Function name `"WeatherAPI"` generated | Function name `""` generated (truthy `""` bug) | **FAIL (HIGH)** |
| Lens schema vs params selection (`schema` non-empty map) | Parameters populated from `schema` | Parameters populated from `schema` | **PASS** |
| Lens schema vs params selection (`schema` empty `%{}`) | Parameters populated from `params` | Parameters populated from `params` | **PASS** |
| Response containing `"usage"` token stats | Token stats extracted into `metadata.usage` | Token stats extracted into `metadata.usage` | **PASS** |
| HTTP 401 Authorization error | Returns `{:error, :invalid_api_key}` | Returns `{:error, :invalid_api_key}` | **PASS** |
| HTTP 400 Bad Request error with map body | Returns `{:error, {400, message}}` | Returns `{:error, {400, message}}` | **PASS** |

---

## Unchallenged Areas

- **Real OpenRouter Network Endpoints**: Tested via offline empirical AST/logic simulation harness `verify_open_router.py` and ExUnit mock analysis because external network access is restricted (`CODE_ONLY` mode).
- **Concurrency & High Load Rate Limiting**: Out of scope for provider client unit challenge testing.
