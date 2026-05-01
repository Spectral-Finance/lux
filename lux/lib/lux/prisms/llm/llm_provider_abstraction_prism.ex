defmodule Lux.Prisms.Llm.LlmProviderAbstractionPrism do
  @moduledoc """
  A prism that provides a universal LLM provider interface with automatic
  model selection, fallback handling, and cost/performance monitoring.

  Supports OpenAI, Anthropic, Google, Ollama, and OpenRouter as providers.

  ## Example

      iex> Lux.Prisms.Llm.LlmProviderAbstractionPrism.run(%{
      ...>   prompt: "Explain quantum computing",
      ...>   provider: "auto",
      ...>   model_preference: ["gpt-4", "claude-3-opus", "gemini-pro"],
      ...>   max_tokens: 500
      ...> })
      {:ok, %{
        "status" => "success",
        "response" => "Quantum computing is...",
        "provider_used" => "openai",
        "model_used" => "gpt-4",
        "tokens_used" => 450,
        "cost_usd" => 0.0135,
        "latency_ms" => 1200
      }}

  The prism reads provider configuration from application config:
  - :llm_openai_api_key - OpenAI API key
  - :llm_anthropic_api_key - Anthropic API key
  - :llm_google_api_key - Google AI API key
  """

  use Lux.Prism,
    name: "LLM Provider Abstraction",
    description: "Universal LLM provider interface with automatic model selection, fallback handling, and cost monitoring",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{
          type: :string,
          description: "The prompt to send to the LLM"
        },
        system_prompt: %{
          type: :string,
          description: "Optional system prompt for context setting"
        },
        provider: %{
          type: :string,
          description: "Specific provider to use, or auto for intelligent selection",
          enum: ["auto", "openai", "anthropic", "google", "ollama", "openrouter"],
          default: "auto"
        },
        model_preference: %{
          type: :array,
          description: "Ordered list of preferred models for auto selection",
          items: %{type: :string}
        },
        max_tokens: %{
          type: :integer,
          description: "Maximum tokens in response",
          default: 1000,
          minimum: 1,
          maximum: 128000
        },
        temperature: %{
          type: :number,
          description: "Sampling temperature (0.0 - 2.0)",
          default: 0.7,
          minimum: 0.0,
          maximum: 2.0
        },
        fallback_enabled: %{
          type: :boolean,
          description: "Enable fallback to next provider on failure",
          default: true
        },
        cost_limit_usd: %{
          type: :number,
          description: "Maximum cost per request in USD",
          default: 0.10
        }
      },
      required: ["prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        response: %{type: :string},
        provider_used: %{type: :string},
        model_used: %{type: :string},
        tokens_used: %{type: :integer},
        cost_usd: %{type: :number},
        latency_ms: %{type: :integer},
        fallback_used: %{type: :boolean}
      },
      required: ["status", "response", "provider_used", "model_used"]
    }

  import Lux.Python

  require Lux.Python

  @provider_priority ["openai", "anthropic", "google", "openrouter", "ollama"]

  @model_costs %{
    "gpt-4" => %{"input" => 0.00003, "output" => 0.00006},
    "gpt-4-turbo" => %{"input" => 0.00001, "output" => 0.00003},
    "gpt-3.5-turbo" => %{"input" => 0.0000005, "output" => 0.0000015},
    "claude-3-opus" => %{"input" => 0.000015, "output" => 0.000075},
    "claude-3-sonnet" => %{"input" => 0.000003, "output" => 0.000015},
    "claude-3-haiku" => %{"input" => 0.00000025, "output" => 0.00000125},
    "gemini-pro" => %{"input" => 0.00000125, "output" => 0.000005},
    "gemini-ultra" => %{"input" => 0.000035, "output" => 0.000105}
  }

  def handler(input, _ctx) do
    with {:ok, result} <- call_provider(input) do
      {:ok, result}
    else
      {:error, reason} when is_binary(reason) ->
        if input["fallback_enabled"] != false do
          attempt_fallback(input, reason)
        else
          {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call_provider(input) do
    python_result =
      python variables: %{input: input} do
        ~PY"""
        import urllib.request
        import json
        import time
        import os

        prompt = input.get("prompt", "")
        system_prompt = input.get("system_prompt", "You are a helpful assistant.")
        provider = input.get("provider", "auto")
        model_preference = input.get("model_preference", [])
        max_tokens = input.get("max_tokens", 1000)
        temperature = input.get("temperature", 0.7)
        cost_limit = input.get("cost_limit_usd", 0.10)

        model_provider_map = {
            "gpt-4": "openai",
            "gpt-4-turbo": "openai",
            "gpt-3.5-turbo": "openai",
            "claude-3-opus": "anthropic",
            "claude-3-sonnet": "anthropic",
            "claude-3-haiku": "anthropic",
            "gemini-pro": "google",
            "gemini-ultra": "google",
        }

        model_costs = {
            "gpt-4": {"input": 0.03, "output": 0.06},
            "gpt-4-turbo": {"input": 0.01, "output": 0.03},
            "gpt-3.5-turbo": {"input": 0.0005, "output": 0.0015},
            "claude-3-opus": {"input": 0.015, "output": 0.075},
            "claude-3-sonnet": {"input": 0.003, "output": 0.015},
            "claude-3-haiku": {"input": 0.00025, "output": 0.00125},
            "gemini-pro": {"input": 0.00125, "output": 0.005},
        }

        provider_defaults = {
            "openai": "gpt-3.5-turbo",
            "anthropic": "claude-3-sonnet",
            "google": "gemini-pro",
            "ollama": "llama3",
            "openrouter": "openai/gpt-3.5-turbo",
        }

        def select_model(prov, prefs):
            if prov == "auto" and prefs:
                for model in prefs:
                    p = model_provider_map.get(model, "")
                    if p:
                        return model, p
            if prov == "auto":
                return "gpt-3.5-turbo", "openai"
            return provider_defaults.get(prov, "gpt-3.5-turbo"), prov

        model, prov = select_model(provider, model_preference)

        input_tokens = len(prompt) // 4
        costs = model_costs.get(model, {"input": 0.001, "output": 0.002})
        est_cost = (input_tokens * costs["input"] + max_tokens * costs["output"]) / 1000

        if est_cost > cost_limit:
            return {
                "status": "error",
                "error": "estimated_cost_exceeds_limit",
                "provider_used": prov,
                "model_used": model,
                "response": "",
                "tokens_used": 0,
                "cost_usd": 0,
                "latency_ms": 0,
                "fallback_used": False
            }

        start = time.time()
        response_text = ""
        tokens = 0
        actual_cost = est_cost

        api_key = os.environ.get("LLM_API_KEY", "")

        if prov == "openai":
            url = "https://api.openai.com/v1/chat/completions"
            body = json.dumps({
                "model": model,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": prompt}
                ],
                "max_tokens": max_tokens,
                "temperature": temperature
            })
            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}"
            }
            try:
                req = urllib.request.Request(url, data=body.encode(), headers=headers)
                resp = urllib.request.urlopen(req, timeout=30)
                data = json.loads(resp.read().decode())
                response_text = data["choices"][0]["message"]["content"]
                tokens = data.get("usage", {}).get("total_tokens", 0)
            except Exception as e:
                response_text = f"API Error: {str(e)}"

        elif prov == "anthropic":
            url = "https://api.anthropic.com/v1/messages"
            body = json.dumps({
                "model": model,
                "max_tokens": max_tokens,
                "messages": [{"role": "user", "content": prompt}],
                "system": system_prompt
            })
            headers = {
                "Content-Type": "application/json",
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01"
            }
            try:
                req = urllib.request.Request(url, data=body.encode(), headers=headers)
                resp = urllib.request.urlopen(req, timeout=30)
                data = json.loads(resp.read().decode())
                response_text = data["content"][0]["text"]
                tokens = data.get("usage", {}).get("output_tokens", 0)
            except Exception as e:
                response_text = f"API Error: {str(e)}"

        elif prov == "google":
            url = f"https://generativelanguage.googleapis.com/v1/models/{model}:generateContent?key={api_key}"
            body = json.dumps({
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"maxOutputTokens": max_tokens, "temperature": temperature}
            })
            try:
                req = urllib.request.Request(url, data=body.encode(), headers={"Content-Type": "application/json"})
                resp = urllib.request.urlopen(req, timeout=30)
                data = json.loads(resp.read().decode())
                response_text = data["candidates"][0]["content"]["parts"][0]["text"]
            except Exception as e:
                response_text = f"API Error: {str(e)}"

        elif prov == "ollama":
            url = "http://localhost:11434/api/generate"
            body = json.dumps({"model": model, "prompt": prompt, "stream": False})
            try:
                req = urllib.request.Request(url, data=body.encode(), headers={"Content-Type": "application/json"})
                resp = urllib.request.urlopen(req, timeout=120)
                data = json.loads(resp.read().decode())
                response_text = data.get("response", "")
            except Exception as e:
                response_text = f"Ollama Error: {str(e)}"

        elif prov == "openrouter":
            url = "https://openrouter.ai/api/v1/chat/completions"
            body = json.dumps({
                "model": model,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": prompt}
                ],
                "max_tokens": max_tokens,
                "temperature": temperature
            })
            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}",
                "HTTP-Referer": "https://lux.dev"
            }
            try:
                req = urllib.request.Request(url, data=body.encode(), headers=headers)
                resp = urllib.request.urlopen(req, timeout=30)
                data = json.loads(resp.read().decode())
                response_text = data["choices"][0]["message"]["content"]
                tokens = data.get("usage", {}).get("total_tokens", 0)
            except Exception as e:
                response_text = f"API Error: {str(e)}"

        latency = int((time.time() - start) * 1000)

        return {
            "status": "success" if response_text and not response_text.startswith("API Error") and not response_text.startswith("Ollama Error") else "error",
            "response": response_text,
            "provider_used": prov,
            "model_used": model,
            "tokens_used": tokens,
            "cost_usd": round(actual_cost, 6),
            "latency_ms": latency,
            "fallback_used": False
        }
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      %{"status" => "error"} = result -> {:error, result["error"] || "provider_error"}
      result when is_map(result) -> {:ok, result}
    end
  end

  defp attempt_fallback(input, _reason) do
    current = input["provider"] || "openai"

    case Enum.find_index(@provider_priority, &(&1 == current)) do
      nil ->
        {:error, "no_fallback_available"}

      idx when idx + 1 < length(@provider_priority) ->
        next_provider = Enum.at(@provider_priority, idx + 1)
        updated_input = input |> Map.put("provider", next_provider) |> Map.put("fallback_enabled", false)
        call_provider(updated_input)

      _ ->
        {:error, "all_providers_exhausted"}
    end
  end
end
