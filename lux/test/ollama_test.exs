defmodule Lux.LLM.OllamaTest do
  use ExUnit.Case, async: false

  alias Lux.LLM.Ollama

  @moduletag :integration
  @moduletag :ollama

  setup_all do
    case Ollama.health_check() do
      :ok ->
        Ollama.init_cache()
        {:ok, %{}}

      {:error, reason} ->
        IO.puts("Skipping Ollama tests: Ollama not reachable (#{reason})")
        :skipped
    end
  end

  setup do
    if setup_all_result() == :skipped do
      :skipped
    else
      :ok
    end
  end

  defp setup_all_result do
    case Ollama.health_check() do
      :ok -> :ok
      _ -> :skipped
    end
  end

  describe "health_check/1" do
    test "returns :ok when server is reachable" do
      assert :ok = Ollama.health_check()
    end
  end

  describe "list_models/1" do
    test "returns list of models" do
      {:ok, models} = Ollama.list_models()
      assert is_list(models)
      assert length(models) > 0
      first = List.first(models)
      assert is_map(first)
      assert Map.has_key?(first, "name")
    end
  end

  describe "available_models/1" do
    test "returns model name strings" do
      {:ok, models} = Ollama.available_models()
      assert is_list(models)
      assert length(models) > 0
      assert is_binary(List.first(models))
    end
  end

  describe "model_info/2" do
    test "returns model details for a known model" do
      {:ok, info} = Ollama.model_info("qwen2.5:7b")
      assert is_map(info)
      assert Map.has_key?(info, "details")
    end

    test "returns :not_found for unknown model" do
      assert {:error, :not_found} = Ollama.model_info("nonexistent-model-xyz-123")
    end
  end

  describe "call/3 (chat completion)" do
    test "returns a valid response for a simple prompt" do
      result = Ollama.call("What is 2+2? Answer with just the number.", [], %{model: "qwen2.5:7b"})

      assert {:ok, response} = result
      assert %Lux.LLM.Response{} = response
      assert response.content != nil
      assert is_binary(response.finish_reason) or is_nil(response.finish_reason)
    end

    test "returns cached response on second identical call" do
      prompt = "What is the capital of France? Answer with just the city name."
      config = %{model: "qwen2.5:7b", cache_enabled: true}

      {:ok, first_response} = Ollama.call(prompt, [], config)

      stats_before = Ollama.cache_stats()

      {:ok, second_response} = Ollama.call(prompt, [], config)

      stats_after = Ollama.cache_stats()

      assert first_response.content == second_response.content
      assert stats_after.hits > stats_before.hits
    end
  end

  describe "generate/2" do
    test "generates text from a prompt" do
      result =
        Ollama.generate("Count from 1 to 3.", %{
          model: "qwen2.5:7b",
          num_predict: 30
        })

      assert {:ok, resp} = result
      assert is_binary(resp[:response])
      assert String.length(resp[:response]) > 0
      assert resp[:eval_count] > 0
    end
  end

  describe "cache_stats/0" do
    test "returns cache statistics map" do
      stats = Ollama.cache_stats()
      assert is_map(stats)
      assert Map.has_key?(stats, :size)
      assert Map.has_key?(stats, :hits)
      assert Map.has_key?(stats, :misses)
      assert Map.has_key?(stats, :evictions)
      assert Map.has_key?(stats, :max_size)
    end
  end

  describe "gpu_monitor/0" do
    test "returns GPU info or error" do
      result = Ollama.gpu_monitor()

      case result do
        {:ok, gpus} ->
          assert is_list(gpus)

          if length(gpus) > 0 do
            gpu = List.first(gpus)
            assert Map.has_key?(gpu, :index)
            assert Map.has_key?(gpu, :name)
            assert Map.has_key?(gpu, :memory_used_mb)
            assert Map.has_key?(gpu, :memory_total_mb)
            assert Map.has_key?(gpu, :gpu_utilization_pct)
          end

        {:error, _reason} ->
          assert true
      end
    end
  end

  describe "gpu_summary/0" do
    test "returns GPU summary or error" do
      result = Ollama.gpu_summary()

      case result do
        {:ok, summary} ->
          assert Map.has_key?(summary, :gpu_count)
          assert Map.has_key?(summary, :total_memory_mb)
          assert Map.has_key?(summary, :used_memory_mb)
          assert Map.has_key?(summary, :free_memory_mb)
          assert Map.has_key?(summary, :avg_gpu_utilization_pct)

        {:error, _reason} ->
          assert true
      end
    end
  end

  describe "benchmark_models/3" do
    @tag :slow
    test "benchmarks multiple models" do
      result = Ollama.benchmark_models(["qwen2.5:7b", "deepseek-coder:latest"], "Say hello", %{num_predict: 5})

      assert {:ok, benchmarks} = result
      assert length(benchmarks) == 2

      Enum.each(benchmarks, fn b ->
        assert Map.has_key?(b, :model)
        assert Map.has_key?(b, :duration_ms)
        assert Map.has_key?(b, :success)
      end)
    end
  end

  describe "delete_model/2" do
    test "returns :not_found for nonexistent model" do
      assert {:error, :not_found} = Ollama.delete_model("nonexistent-model-xyz-123")
    end
  end
end
