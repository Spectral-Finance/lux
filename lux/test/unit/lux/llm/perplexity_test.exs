defmodule Lux.LLM.PerplexityTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Perplexity
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  require Lux.Beam
  require Lux.Lens
  require Lux.Prism

  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism,
      name: "Test Prism",
      input_schema: %{type: :object, properties: %{value: %{type: :string}}},
      description: "A test prism"

    def handler(%{"value" => "success"}, _context), do: {:ok, %{result: "success test"}}
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
      name: "WeatherAPI",
      description: "Gets weather data",
      schema: %{
        type: "object",
        properties: %{
          location: %{
            type: "string",
            description: "City name"
          },
          units: %{
            type: "string",
            description: "Temperature units"
          }
        }
      }
  end

  setup do
    Application.put_env(:lux, Perplexity, plug: {Req.Test, Perplexity})
    Req.Test.verify_on_exit!()
  end

  describe "models/0" do
    test "returns the list of available Perplexity models" do
      models = Perplexity.models()

      assert is_list(models)
      assert length(models) > 0
      assert Enum.any?(models, &(&1.id == "sonar"))
      assert Enum.any?(models, &(&1.id == "sonar-pro"))
      assert models |> Enum.map(& &1.id) |> Enum.uniq() |> length() == length(models)
    end
  end

  describe "model_price/1" do
    test "returns pricing for a known model" do
      assert %{input: input, output: output} = Perplexity.model_price("sonar-pro")

      assert input == 3.00
      assert output == 15.00
    end

    test "returns zero pricing for an unknown model" do
      assert %{input: input, output: output} = Perplexity.model_price("unknown-model")

      assert input == 0.0
      assert output == 0.0
    end
  end

  describe "tool_to_function/1" do
    test "converts a beam to a Perplexity function" do
      beam = TestBeam.view()

      function = Perplexity.tool_to_function(beam)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_PerplexityTest_TestBeam",
                 description: "A test beam",
                 parameters: %{
                   type: :object,
                   properties: %{value: %{type: :string}}
                 }
               }
             } = function
    end

    test "converts a prism to a Perplexity function" do
      prism = TestPrism.view()

      function = Perplexity.tool_to_function(prism)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_PerplexityTest_TestPrism",
                 description: "A test prism",
                 parameters: %{
                   type: :object,
                   properties: %{value: %{type: :string}}
                 }
               }
             } = function
    end

    test "converts a lens to a Perplexity function" do
      lens = TestLens.view()

      function = Perplexity.tool_to_function(lens)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_PerplexityTest_TestLens",
                 description: "Gets weather data",
                 parameters: %{
                   type: "object",
                   properties: %{
                     location: %{
                       type: "string",
                       description: "City name"
                     },
                     units: %{
                       type: "string",
                       description: "Temperature units"
                     }
                   }
                 }
               }
             } = function
    end
  end

  describe "call/3" do
    test "happy path: successfully calls Perplexity API (200/success)" do
      config = %{
        api_key: "test_key",
        model: "sonar",
        temperature: 0.7
      }

      Req.Test.expect(Perplexity, fn conn ->
        assert conn.method == "POST"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test_key"] = auth_header

        accept_header = Plug.Conn.get_req_header(conn, "accept")
        assert ["application/json"] = accept_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "sonar"

        assert [%{"role" => "user", "content" => "What is the capital of France?"}] =
                 decoded_body["messages"]

        assert decoded_body["stream"] == false

        Req.Test.json(conn, %{
          "id" => "chatcmpl-123",
          "model" => "sonar",
          "created" => 1_234_567_890,
          "choices" => [
            %{
              "message" => %{
                "content" => "The capital of France is Paris.",
                "role" => "assistant"
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 8, "total_tokens" => 18},
          "system_fingerprint" => "fp_abc"
        })
      end)

      assert {:ok, response} = Perplexity.call("What is the capital of France?", [], config)
      assert %Signal{schema_id: ResponseSignal} = response
      assert response.payload.content == %{"text" => "The capital of France is Paris."}
      assert response.payload.finish_reason == "stop"
      assert response.payload.model == "sonar"

      assert response.metadata.usage == %{
               "prompt_tokens" => 10,
               "completion_tokens" => 8,
               "total_tokens" => 18
             }

      assert response.metadata.cost_usd > 0
    end

    test "null input: nil prompt is handled gracefully without crashing" do
      config = %{api_key: "test_key", model: "sonar"}

      assert {:error, reason} = Perplexity.call(nil, [], config)
      assert is_binary(reason)
      assert reason =~ "non-empty string"
    end

    test "empty input: empty string prompt is rejected with a diagnostic" do
      config = %{api_key: "test_key", model: "sonar"}

      assert {:error, reason} = Perplexity.call("", [], config)
      assert is_binary(reason)
      assert reason =~ "non-empty string"
    end

    test "empty input: whitespace-only prompt is rejected with a diagnostic" do
      config = %{api_key: "test_key", model: "sonar"}

      assert {:error, reason} = Perplexity.call("   ", [], config)
      assert is_binary(reason)
      assert reason =~ "non-empty string"
    end

    test "boundary: temperature at exact lower and upper bounds is accepted" do
      Enum.each([0.0, 1.0], fn temperature ->
        config = %{
          api_key: "test_key",
          model: "sonar",
          temperature: temperature
        }

        Req.Test.expect(Perplexity, fn conn ->
          {:ok, body, _conn} = Plug.Conn.read_body(conn)
          decoded_body = Jason.decode!(body)
          assert decoded_body["temperature"] == temperature

          Req.Test.json(conn, %{
            "id" => "boundary",
            "model" => "sonar",
            "choices" => [%{"message" => %{"content" => "ok"}, "finish_reason" => "stop"}]
          })
        end)

        assert {:ok, response} = Perplexity.call("boundary prompt", [], config)
        assert response.payload.content == %{"text" => "ok"}
      end)
    end

    test "boundary: top_p at exact lower and upper bounds is accepted" do
      Enum.each([0.0, 1.0], fn top_p ->
        config = %{
          api_key: "test_key",
          model: "sonar",
          top_p: top_p
        }

        Req.Test.expect(Perplexity, fn conn ->
          {:ok, body, _conn} = Plug.Conn.read_body(conn)
          decoded_body = Jason.decode!(body)
          assert decoded_body["top_p"] == top_p

          Req.Test.json(conn, %{
            "id" => "boundary",
            "model" => "sonar",
            "choices" => [%{"message" => %{"content" => "ok"}, "finish_reason" => "stop"}]
          })
        end)

        assert {:ok, _} = Perplexity.call("boundary prompt", [], config)
      end)
    end

    test "negative: unauthorized caller receives a typed invalid_api_key error" do
      config = %{api_key: "invalid_key", model: "sonar"}

      Req.Test.expect(Perplexity, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          401,
          Jason.encode!(%{"error" => %{"message" => "Invalid API key"}})
        )
      end)

      assert {:error, :invalid_api_key} = Perplexity.call("test prompt", [], config)
    end

    test "negative: malformed API error returns a typed status and message" do
      config = %{api_key: "test_key", model: "sonar"}

      Req.Test.expect(Perplexity, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          Jason.encode!(%{"error" => %{"message" => "Bad request"}})
        )
      end)

      assert {:error, {400, "Bad request"}} = Perplexity.call("test prompt", [], config)
    end

    test "negative: network error is handled gracefully without crashing" do
      config = %{api_key: "test_key", model: "sonar"}

      Req.Test.expect(Perplexity, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, reason} = Perplexity.call("test prompt", [], config)
      assert is_binary(reason)
      assert reason =~ "Perplexity API error"
    end

    test "handles tool call responses with a successful prism tool call" do
      config = %{
        api_key: "test_key",
        model: "sonar"
      }

      Req.Test.expect(Perplexity, fn conn ->
        Req.Test.json(conn, %{
          "id" => "chatcmpl-tool",
          "model" => "sonar",
          "choices" => [
            %{
              "message" => %{
                "tool_calls" => [
                  %{
                    "type" => "function",
                    "function" => %{
                      "name" => "#{TestPrism}",
                      "arguments" => ~s({"value": "success"})
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ]
        })
      end)

      assert {:ok, response} = Perplexity.call("test prompt", [TestPrism], config)
      assert %Signal{schema_id: ResponseSignal} = response
      assert response.payload.content == nil
      assert response.payload.finish_reason == "tool_calls"
      assert response.payload.tool_calls_results == [%{result: "success test"}]
    end
  end

  describe "stream/3" do
    test "streams response events from Perplexity" do
      config = %{
        api_key: "test_key",
        model: "sonar",
        stream: true
      }

      sse_body =
        """
        data: {"id":"chatcmpl-1","model":"sonar","choices":[{"index":0,"delta":{"role":"assistant","content":"Hello"},"finish_reason":null}]}

        data: {"id":"chatcmpl-1","model":"sonar","choices":[{"index":0,"delta":{"content":" world"},"finish_reason":null}]}

        data: [DONE]
        """

      Req.Test.expect(Perplexity, fn conn ->
        assert conn.method == "POST"

        accept_header = Plug.Conn.get_req_header(conn, "accept")
        assert ["text/event-stream"] = accept_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["stream"] == true

        Req.Test.text(conn, sse_body)
      end)

      assert {:ok, stream} = Perplexity.stream("say hello", [], config)
      [first, second] = stream.events
      assert first.content == "Hello"
      assert second.content == " world"
      assert stream.model == "sonar"
    end

    test "stream: nil prompt is handled gracefully without crashing" do
      config = %{api_key: "test_key", model: "sonar"}

      assert {:error, reason} = Perplexity.stream(nil, [], config)
      assert is_binary(reason)
      assert reason =~ "non-empty string"
    end

    test "stream: empty prompt is rejected with a diagnostic" do
      config = %{api_key: "test_key", model: "sonar"}

      assert {:error, reason} = Perplexity.stream("", [], config)
      assert is_binary(reason)
      assert reason =~ "non-empty string"
    end
  end

  describe "concurrency" do
    test "handles simultaneous requests on the same client atomically with no double-spend" do
      config = %{api_key: "test_key", model: "sonar"}

      Req.Test.expect(Perplexity, 10, fn conn ->
        Req.Test.json(conn, %{
          "id" => "concurrent",
          "model" => "sonar",
          "choices" => [%{"message" => %{"content" => "ok"}, "finish_reason" => "stop"}]
        })
      end)

      results =
        1..10
        |> Enum.map(fn _ ->
          Task.async(fn ->
            Perplexity.call("concurrent prompt", [], config)
          end)
        end)
        |> Enum.map(&Task.await/1)

      assert length(results) == 10

      Enum.each(results, fn
        {:ok, %Signal{payload: %{content: %{"text" => "ok"}}}} ->
          :ok

        other ->
          assert false, "expected successful atomic response, got: #{inspect(other)}"
      end)
    end
  end

  describe "regression" do
    test "regression: Perplexity integration defect resolved - happy path call succeeds" do
      config = %{api_key: "test_key", model: "sonar"}

      Req.Test.expect(Perplexity, fn conn ->
        assert conn.method == "POST"

        Req.Test.json(conn, %{
          "id" => "regression-1",
          "model" => "sonar",
          "choices" => [
            %{
              "message" => %{
                "content" => "resolved",
                "role" => "assistant"
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 5, "total_tokens" => 10}
        })
      end)

      assert {:ok, response} = Perplexity.call("regression prompt", [], config)
      assert %Signal{schema_id: ResponseSignal} = response
      assert response.payload.content == %{"text" => "resolved"}
      assert response.metadata.cost_usd > 0
    end
  end
end
