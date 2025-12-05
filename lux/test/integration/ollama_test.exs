defmodule Lux.LLM.OllamaTest do
  @moduledoc """
  Integration tests for Ollama LLM provider.

  These tests require a running Ollama instance at localhost:11434.
  Skip these tests if Ollama is not available.
  """

  use ExUnit.Case, async: false

  alias Lux.LLM.Ollama

  @moduletag :integration
  @moduletag :ollama

  setup_all do
    case Ollama.health_check() do
      :ok ->
        :ok

      {:error, :ollama_not_running} ->
        ExUnit.configure(exclude: [:ollama])
        :ok
    end
  end

  describe "health_check/1" do
    test "returns :ok when Ollama is running" do
      assert :ok = Ollama.health_check()
    end
  end

  describe "list_models/1" do
    test "returns list of available models" do
      assert {:ok, models} = Ollama.list_models()
      assert is_list(models)
    end
  end

  describe "call/3" do
    @tag timeout: 120_000
    test "simple text request returns valid response" do
      config = %{
        model: get_test_model(),
        json_response: false
      }

      result = Ollama.call("What is 2 + 2? Reply with just the number.", [], config)

      assert {:ok, %Lux.Signal{}} = result
    end

    @tag timeout: 120_000
    test "JSON response request returns structured output" do
      config = %{
        model: get_test_model(),
        json_response: true
      }

      result =
        Ollama.call(
          ~s(Return a JSON object with keys "capital" and "country" for France.),
          [],
          config
        )

      case result do
        {:ok, %Lux.Signal{payload: payload}} ->
          assert is_map(payload.content) or is_binary(payload.content)

        {:error, reason} ->
          flunk("Expected success, got error: #{inspect(reason)}")
      end
    end

    @tag timeout: 120_000
    test "handles model not found error gracefully" do
      config = %{
        model: "nonexistent-model-12345",
        json_response: false
      }

      result = Ollama.call("Hello", [], config)

      # Should return an error for non-existent model
      assert {:error, _} = result
    end
  end

  describe "show_model/2" do
    test "returns model information for existing model" do
      case Ollama.list_models() do
        {:ok, [model | _]} ->
          model_name = model["name"]
          assert {:ok, info} = Ollama.show_model(model_name)
          assert is_map(info)

        {:ok, []} ->
          # No models available, skip test
          :ok
      end
    end

    test "returns error for non-existent model" do
      assert {:error, _} = Ollama.show_model("nonexistent-model-xyz")
    end
  end

  describe "ensure_model/2" do
    @tag timeout: 600_000
    @tag :slow
    test "returns model info if model exists" do
      case Ollama.list_models() do
        {:ok, [model | _]} ->
          model_name = model["name"]
          assert {:ok, _info} = Ollama.ensure_model(model_name)

        {:ok, []} ->
          # No models, skip
          :ok
      end
    end
  end

  # Helper to get a test model that's likely to be available
  defp get_test_model do
    case Ollama.list_models() do
      {:ok, [model | _]} ->
        model["name"]

      {:ok, []} ->
        # Fallback to common model names
        "llama3.2"

      {:error, _} ->
        "llama3.2"
    end
  end
end
