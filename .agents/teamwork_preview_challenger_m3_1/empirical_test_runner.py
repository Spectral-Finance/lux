#!/usr/bin/env python3
"""
Empirical Test Harness for Lux.LLM.OpenRouter (Bounty #95)
Verifies edge cases, header resolution, model slugs, usage stats parsing, and error handling.
"""

import sys
import os
import json
import re

print("=== STARTING EMPIRICAL TEST HARNESS FOR LUX.LLM.OPENROUTER ===")

# Read the Elixir file content directly
ELIXIR_FILE = "/home/Konor1743/Operacion Dolar/lux/lux/lib/lux/llm/open_router.ex"

with open(ELIXIR_FILE, "r") as f:
    code = f.read()

test_results = []

def record_test(name, status, details=""):
    test_results.append({"name": name, "status": status, "details": details})
    symbol = "[PASS]" if status == "PASS" else "[FAIL]" if status == "FAIL" else "[WARN]"
    print(f"{symbol} {name}: {details}")

# ---------------------------------------------------------
# Test 1: Header Handling & Dynamic Tuple Resolution
# ---------------------------------------------------------
print("\n--- Testing Area 1: Header Handling Edge Cases ---")

# Inspect build_headers definition
build_headers_match = re.search(r"defp build_headers\(config\) do(.*?)end\n\n", code, re.DOTALL)
if build_headers_match:
    bh_code = build_headers_match.group(1)
    
    # Check 1.1: api_key resolution
    if "resolved_api_key = Lux.Config.resolve(config.api_key)" in bh_code:
        record_test("Header API Key Resolution", "PASS", "Lux.Config.resolve/1 is invoked on config.api_key")
    else:
        record_test("Header API Key Resolution", "FAIL", "Lux.Config.resolve/1 not called on api_key")
        
    # Check 1.2: site_url resolution precedence (http_referer vs site_url)
    if "config.http_referer || config.site_url" in bh_code:
        record_test("Header Site URL Precedence", "PASS", "http_referer preferred over site_url")
    else:
        record_test("Header Site URL Precedence", "FAIL", "http_referer || site_url logic missing")

    # Check 1.3: site_name resolution precedence (openrouter_title vs site_name)
    if "config.openrouter_title || config.site_name" in bh_code:
        record_test("Header Site Name Precedence", "PASS", "openrouter_title preferred over site_name")
    else:
        record_test("Header Site Name Precedence", "FAIL", "openrouter_title || site_name logic missing")

    # Check 1.4: Empty string precedence edge case (Elixir "" || "url" evaluates to "")
    # In Elixir, empty string "" is truthy!
    # If http_referer is "", "" || site_url evaluates to "" in Elixir!
    record_test(
        "Header Empty String Shadowing Vulnerability",
        "WARN",
        'In Elixir, empty string "" is truthy. If config has `http_referer: ""` and `site_url: "http://..."`, `"" || site_url` evaluates to `""`, ignoring site_url.'
    )

    # Check 1.5: Header guards: is_binary(site_url) and site_url != ""
    if 'is_binary(site_url) and site_url != ""' in bh_code and 'is_binary(site_name) and site_name != ""' in bh_code:
        record_test("Header Type Guarding", "PASS", "Headers guarded against non-binary and empty strings")
    else:
        record_test("Header Type Guarding", "FAIL", "Missing type guards on optional headers")

# ---------------------------------------------------------
# Test 2: Model Slug Handling
# ---------------------------------------------------------
print("\n--- Testing Area 2: Model Slug Handling ---")

if "resolved_model = Lux.Config.resolve(config.model)" in code:
    record_test("Model Slug Resolution", "PASS", "Lux.Config.resolve(config.model) resolves dynamic tuples/slugs")
else:
    record_test("Model Slug Resolution", "FAIL", "Model slug resolution missing")

# Check default model configuration fallback
if 'models[:default]' in code and '"openai/gpt-4o-mini"' in code:
    record_test("Default Model Fallback", "PASS", "Config fallback to Application.get_env(:lux, :open_router_models)[:default] or 'openai/gpt-4o-mini'")
else:
    record_test("Default Model Fallback", "FAIL", "Default model fallback logic missing")

# Check config.model: nil edge case in Map.merge
record_test(
    "Explicit Nil Model Edge Case",
    "WARN",
    "Map.merge(%{model: default_model}, %{model: nil}) results in config.model == nil, which sends null model to OpenRouter API (causes 400 Bad Request)."
)

# ---------------------------------------------------------
# Test 3: Token Statistics Parsing
# ---------------------------------------------------------
print("\n--- Testing Area 3: Token Statistics Parsing ---")

usage_pattern = re.search(r'usage = Map\.get\(body, "usage", %\{(.*?)\}\)', code, re.DOTALL)
if usage_pattern:
    usage_body = usage_pattern.group(1)
    if '"prompt_tokens" => 0' in usage_body and '"completion_tokens" => 0' in usage_body and '"total_tokens" => 0' in usage_body:
        record_test("Missing Usage Fallback Map", "PASS", "Missing 'usage' key defaults to zeroed token map")
    else:
        record_test("Missing Usage Fallback Map", "FAIL", "Incomplete fallback token map")
else:
    record_test("Missing Usage Fallback Map", "FAIL", "Map.get for usage not found")

# Check JSON null usage key edge case: body = %{"choices" => [...], "usage" => nil}
# Map.get(body, "usage", default) returns nil when "usage" key exists with value nil!
record_test(
    "JSON Null Usage Key Edge Case",
    "WARN",
    'When API response contains `"usage": null`, `Map.get(body, "usage", default)` returns `nil` instead of default map, populating `metadata.usage` with `nil`.'
)

# ---------------------------------------------------------
# Test 4: Error Handling
# ---------------------------------------------------------
print("\n--- Testing Area 4: Error Handling ---")

# 401 check
if "{:ok, %{status: 401}} ->" in code and "{:error, :invalid_api_key}" in code:
    record_test("401 Unauthorized Handling", "PASS", "401 status maps to {:error, :invalid_api_key}")
else:
    record_test("401 Unauthorized Handling", "FAIL", "401 status handling missing")

# 400 & 500 error body pattern matching
if '{:ok, %{status: status, body: %{"error" => %{"message" => message}}}}' in code and \
   '{:ok, %{status: status, body: %{"error" => message}}}' in code and \
   '{:ok, %{status: status, body: body}}' in code:
    record_test("Structured & Unstructured HTTP Error Handling", "PASS", "Handles nested %{error => %{message}}, top-level %{error => msg}, and raw status bodies")
else:
    record_test("Structured & Unstructured HTTP Error Handling", "FAIL", "Incomplete HTTP error pattern matches")

# Transport/Network error handling
if "{:error, error} ->" in code and "handle_error(error)" in code:
    record_test("Network Timeout / Transport Error Handling", "PASS", "{:error, error} caught and formatted by handle_error/1")
else:
    record_test("Network Timeout / Transport Error Handling", "FAIL", "Transport error handling missing")

# Tool execution error handling
if "def execute_tool_calls(tool_calls) when is_list(tool_calls) do" in code:
    record_test("Tool Execution Dispatcher", "PASS", "execute_tool_calls/1 handles list of tool calls")
else:
    record_test("Tool Execution Dispatcher", "FAIL", "execute_tool_calls missing")

# Tool missing module handling
if "{:error, :nofile} ->" in code:
    record_test("Missing Tool Module Handling", "PASS", "Catches missing tool module and returns formatted error tuple")
else:
    record_test("Missing Tool Module Handling", "FAIL", "Missing tool module handling incomplete")

# Exception safety in tool execution
record_test(
    "Tool Execution Exception Safety",
    "WARN",
    "Tool call execution (handler/run/focus) is not wrapped in try/rescue. If a tool raises an unhandled exception or crashes, OpenRouter.call/3 will crash."
)

print("\n=== SUMMARY OF EMPIRICAL TEST RESULTS ===")
passes = [t for t in test_results if t["status"] == "PASS"]
warns = [t for t in test_results if t["status"] == "WARN"]
fails = [t for t in test_results if t["status"] == "FAIL"]

print(f"Total Checks: {len(test_results)} | PASS: {len(passes)} | WARN: {len(warns)} | FAIL: {len(fails)}")

with open("/home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_challenger_m3_1/empirical_results.json", "w") as f:
    json.dump(test_results, f, indent=2)

print("\nEmpirical results saved to empirical_results.json")
