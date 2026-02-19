defmodule Lux.LLM.FallbackChainTest do
  use UnitAPICase, async: false

  alias Lux.LLM.FallbackChain
  alias Lux.LLM.Registry

  describe "new/2" do
    test "creates a chain with defaults" do
      chain =
        FallbackChain.new([
          {:openai, %{model: "gpt-4o"}},
          {:anthropic, %{model: "claude-3-5-sonnet-20241022"}}
        ])

      assert length(chain.providers) == 2
      assert chain.max_retries == 1
      assert chain.base_backoff_ms == 100
      assert chain.circuit_breaker_threshold == 5
    end

    test "creates a chain with custom options" do
      chain =
        FallbackChain.new(
          [{:openai, %{}}],
          max_retries: 3,
          base_backoff_ms: 200,
          circuit_breaker_threshold: 10
        )

      assert chain.max_retries == 3
      assert chain.base_backoff_ms == 200
      assert chain.circuit_breaker_threshold == 10
    end
  end

  describe "call/4" do
    test "succeeds with first provider" do
      Req.Test.expect(Lux.LLM.OpenAI, fn conn ->
        Req.Test.json(conn, %{
          "model" => "gpt-4o",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"result": "success"})
              },
              "finish_reason" => "stop"
            }
          ]
        })
      end)

      chain =
        FallbackChain.new([
          {:openai, %{model: "gpt-4o", api_key: "test"}}
        ])

      result = FallbackChain.call(chain, "test", [], %{})

      assert {:ok, _response, :openai} = result
    end

    test "falls back to second provider when first fails" do
      # First provider (openai) fails - need 2 expects (1 original + 1 retry)
      for _ <- 1..2 do
        Req.Test.expect(Lux.LLM.OpenAI, fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => %{"message" => "Server error"}}))
        end)
      end

      # Second provider (anthropic) succeeds
      Req.Test.expect(Lux.LLM.Anthropic, fn conn ->
        Req.Test.json(conn, %{
          "id" => "msg_123",
          "type" => "message",
          "role" => "assistant",
          "content" => [
            %{"type" => "text", "text" => "Success from Anthropic"}
          ],
          "model" => "claude-3-5-sonnet-20241022",
          "stop_reason" => "end_turn"
        })
      end)

      chain =
        FallbackChain.new(
          [
            {:openai, %{model: "gpt-4o", api_key: "test"}},
            {:anthropic, %{model: "claude-3-5-sonnet-20241022", api_key: "test"}}
          ],
          max_retries: 1,
          base_backoff_ms: 10
        )

      result = FallbackChain.call(chain, "test", [], %{})

      assert {:ok, _response, :anthropic} = result
    end

    test "returns all errors when all providers fail" do
      # OpenAI: 2 attempts (1 + 1 retry)
      for _ <- 1..2 do
        Req.Test.expect(Lux.LLM.OpenAI, fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => %{"message" => "OpenAI down"}}))
        end)
      end

      # Anthropic: 2 attempts (1 + 1 retry)
      for _ <- 1..2 do
        Req.Test.expect(Lux.LLM.Anthropic, fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Anthropic down"}))
        end)
      end

      chain =
        FallbackChain.new(
          [
            {:openai, %{model: "gpt-4o", api_key: "test"}},
            {:anthropic, %{model: "claude-3-opus-20240229", api_key: "test"}}
          ],
          max_retries: 1,
          base_backoff_ms: 10
        )

      result = FallbackChain.call(chain, "test", [], %{})

      assert {:error, errors} = result
      assert length(errors) == 2
    end

    test "skips providers with open circuit breaker" do
      # Simulate many consecutive errors for a provider
      for _ <- 1..10 do
        Registry.report_health(:circuit_test_provider, :error, 100)
      end

      # Register the provider
      Registry.register(:circuit_test_provider, Lux.LLM.OpenAI)

      Req.Test.expect(Lux.LLM.Anthropic, fn conn ->
        Req.Test.json(conn, %{
          "id" => "msg_123",
          "type" => "message",
          "role" => "assistant",
          "content" => [%{"type" => "text", "text" => "Anthropic worked"}],
          "model" => "claude-3-5-sonnet-20241022",
          "stop_reason" => "end_turn"
        })
      end)

      chain =
        FallbackChain.new(
          [
            {:circuit_test_provider, %{model: "gpt-4o", api_key: "test"}},
            {:anthropic, %{model: "claude-3-5-sonnet-20241022", api_key: "test"}}
          ],
          circuit_breaker_threshold: 5
        )

      result = FallbackChain.call(chain, "test", [], %{})

      assert {:ok, _response, :anthropic} = result

      # Cleanup
      Registry.unregister(:circuit_test_provider)
    end
  end
end
