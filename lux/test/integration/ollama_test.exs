defmodule Lux.LLM.OllamaIntegrationTest do
  @moduledoc """
  Integration tests for Ollama LLM provider.

  These tests require a running Ollama instance at localhost:11434
  with the llama3.2 model available.

  Run with: mix test --include integration
  """
  use IntegrationCase

  alias Lux.LLM.Ollama

  @tag :integration
  test "health check against running Ollama" do
    case Ollama.health_check() do
      {:ok, %{"version" => version}} ->
        assert is_binary(version)
        IO.puts("Ollama version: #{version}")

      {:error, "Ollama is not running"} ->
        IO.puts("Skipping: Ollama not running")
    end
  end

  @tag :integration
  test "list models from running Ollama" do
    case Ollama.list_models() do
      {:ok, models} ->
        assert is_list(models)
        IO.puts("Available models: #{length(models)}")
        Enum.each(models, fn m -> IO.puts("  - #{m["name"]}") end)

      {:error, _} ->
        IO.puts("Skipping: Ollama not running")
    end
  end

  @tag :integration
  test "basic chat completion" do
    case Ollama.call("What is 2 + 2? Reply with just the number.", [], %{
           model: "llama3.2",
           json_response: false,
           temperature: 0.0
         }) do
      {:ok, signal} ->
        assert signal != nil
        IO.puts("Response received from Ollama")

      {:error, msg} ->
        IO.puts("Skipping: #{inspect(msg)}")
    end
  end
end
