# Adversarial Challenge Report — Lux OpenRouter API Integration (Bounty #95)

## Challenge Summary

**Overall risk assessment**: MEDIUM

Adversarial stress-testing of `Lux.LLM.OpenRouter` was conducted across header handling, model slug parsing, token statistics extraction, HTTP error status mapping, and tool call execution. While the overall implementation functions correctly for standard workflows, 4 potential failure modes/edge-case vulnerabilities were identified.

---

## Challenges

### 1. [Medium] In-Memory Tool Execution Crash Vulnerability (Lack of Exception Rescue)
- **Assumption challenged**: Assumes all tool executions (`handler`, `run`, `focus`) succeed or return standard `{:ok, ...}` / `{:error, ...}` tuples without raising unhandled runtime exceptions.
- **Attack scenario**: An invoked Beam, Prism, or Lens tool throws an unhandled exception (e.g. `ArgumentError`, `KeyError`, DB connectivity failure, or crash).
- **Blast radius**: `OpenRouter.call/3` does not wrap tool execution in a `try...rescue` block. A tool crash causes the entire caller process to crash rather than returning a structured `{:error, reason}` tuple.
- **Mitigation**: Wrap `execute_tool/3` invocation in `try...rescue` to capture exceptions cleanly and return `{:error, "Tool exception: " <> Exception.message(e)}`.

### 2. [Low] Null `"usage"` Field in OpenRouter JSON Responses
- **Assumption challenged**: Assumes `"usage"` key is either missing or contains a valid map.
- **Attack scenario**: OpenRouter API streams or returns a response where `"usage": null` in the raw JSON payload.
- **Blast radius**: `Map.get(body, "usage", %{"prompt_tokens" => 0, ...})` returns `nil` when the key `"usage"` is present with explicit JSON `null`. Downstream signal metadata `metadata.usage` is set to `nil`, which may break code expecting `metadata.usage` to be a map.
- **Mitigation**: Replace `Map.get(body, "usage", default)` with `body["usage"] || %{"prompt_tokens" => 0, "completion_tokens" => 0, "total_tokens" => 0}`.

### 3. [Low] Empty String (`""`) Precedence Shadowing in Site Attribution Headers
- **Assumption challenged**: Assumes `config.http_referer || config.site_url` fall back to `site_url` if `http_referer` is empty.
- **Attack scenario**: A user or higher-level caller passes `%{http_referer: "", site_url: "https://my-app.com"}`.
- **Blast radius**: In Elixir, empty string `""` is truthy (`"" || "https://my-app.com"` evaluates to `""`). The header lookup selects `""`, which fails the `site_url != ""` check, so neither `HTTP-Referer` nor `site_url` is added to the request headers.
- **Mitigation**: Check presence via binary length or `presence` helper (e.g. `(if is_binary(ref) and ref != "", do: ref, else: config.site_url)`).

### 4. [Low] Explicit `model: nil` Overwriting Default Model Configuration
- **Assumption challenged**: Assumes passing `%{model: nil}` in `config` uses default model.
- **Attack scenario**: Caller invokes `OpenRouter.call(prompt, tools, %{model: nil})`.
- **Blast radius**: `Map.merge(%{model: default_model, api_key: default_api_key}, %{model: nil})` overwrites `default_model` with `nil`. The resulting `config.model` is `nil`, sending `"model": null` in the API payload and triggering an HTTP 400 Bad Request.
- **Mitigation**: Use `config[:model] || default_model` during struct initialization.

---

## Stress Test Results

| # | Scenario | Expected Behavior | Actual / Predicted Behavior | Result |
|---|----------|-------------------|-----------------------------|--------|
| 1 | Standard API Call & Usage Stats | Returns `ResponseSignal` with `metadata.usage` map | Correctly returns signal & usage | **PASS** |
| 2 | Dynamic Tuple Key Resolution (`{:env, "KEY"}`) | `Lux.Config.resolve/1` evaluates environment variables | Evaluates `{:env, ...}` for headers & endpoint | **PASS** |
| 3 | Model Slug with `~` Prefix (`~openai/gpt-latest`) | Preserves `~` prefix in JSON body payload | Preserves `~openai/gpt-latest` unchanged | **PASS** |
| 4 | Custom Provider Model Slugs (`meta-llama/...`) | Transmits exact string binary in JSON | Transmits custom slug unchanged | **PASS** |
| 5 | HTTP Status 401 Unauthorized | Returns `{:error, :invalid_api_key}` | Returns `{:error, :invalid_api_key}` | **PASS** |
| 6 | HTTP Status 400 Bad Request (Nested vs Text) | Returns `{:error, {400, message}}` | Formats both JSON and string error bodies | **PASS** |
| 7 | HTTP Status 500 Internal Server Error | Returns `{:error, {500, message}}` | Formats both JSON and string HTML error bodies | **PASS** |
| 8 | Network / Receive Timeout | Returns `{:error, "OpenRouter API error: ..."}` | Formats transport error via `handle_error/1` | **PASS** |
| 9 | Missing Tool Module (`NonExistentModule`) | Returns `{:error, "Failed to load tool module..."}` | Safely handles missing tool module | **PASS** |
| 10 | Malformed Tool Arguments JSON (`{invalid}`) | Returns `{:error, "Failed to decode..."}` | Safely handles JSON decode failure | **PASS** |
| 11 | Tool execution raises runtime exception | Returns `{:error, reason}` | Crashes process due to missing rescue | **WARN** |
| 12 | API response returns `"usage": null` | `metadata.usage` defaults to zero map | `metadata.usage` set to `nil` | **WARN** |
| 13 | Header with empty string `http_referer: ""` | Falls back to `site_url` | Header omitted entirely due to `""` truthiness | **WARN** |

---

## Unchallenged Areas

- Real OpenRouter streaming responses (`stream: true` SSE / server-sent events) — out of scope for current Bounty #95 non-streaming completion contract.
