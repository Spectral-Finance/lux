defmodule Lux.LLM.OllamaTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Ollama
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
    Req.Test.verify_on_exit!()
  end

  describe "tool_to_function/1" do
    test "converts a beam to an Ollama function" do
      beam = TestBeam.view()

      function = Ollama.tool_to_function(beam)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OllamaTest_TestBeam",
                 description: "A test beam",
                 parameters: %{
                   type: "object",
                   properties: %{
                     value: %{type: "string"}
                   }
                 }
               }
             } = function
    end

    test "converts a prism to an Ollama function" do
      prism = TestPrism.view()

      function = Ollama.tool_to_function(prism)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OllamaTest_TestPrism",
                 description: "A test prism",
                 parameters: %{
                   type: "object",
                   properties: %{
                     value: %{type: "string"}
                   }
                 }
               }
             } = function
    end

    test "converts a lens to an Ollama function" do
      lens = TestLens.view()

      function = Ollama.tool_to_function(lens)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OllamaTest_TestLens",
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
    test "makes correct API call and returns response signal" do
      config = %{
        model: "llama3.2:latest"
      }

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "llama3.2:latest"
        assert decoded_body["stream"] == false
        assert [%{"role" => "user", "content" => "Hello!"}] = decoded_body["messages"]
        assert is_map(decoded_body["options"])
        assert decoded_body["format"] == "json"

        Req.Test.json(conn, %{
          "model" => "llama3.2:latest",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"greeting": "Hello! How can I help you?"})
          },
          "done" => true,
          "done_reason" => "stop",
          "total_duration" => 5_000_000_000,
          "load_duration" => 1_000_000_000,
          "prompt_eval_count" => 10,
          "prompt_eval_duration" => 500_000_000,
          "eval_count" => 25,
          "eval_duration" => 3_500_000_000
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"greeting" => "Hello! How can I help you?"},
                  finish_reason: "stop",
                  model: "llama3.2:latest",
                  tool_calls: nil,
                  tool_calls_results: nil
                },
                metadata: %{
                  performance: %{
                    total_duration_ns: 5_000_000_000,
                    eval_count: 25,
                    tokens_per_second: _tps
                  },
                  usage: %{
                    "prompt_tokens" => 10,
                    "completion_tokens" => 25,
                    "total_tokens" => 35
                  }
                }
              }} = Ollama.call("Hello!", [], config)
    end

    test "sends system message when configured" do
      config = %{
        model: "llama3.2:latest",
        system: "You are a helpful assistant."
      }

      Req.Test.expect(Ollama, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert [
                 %{"role" => "system", "content" => "You are a helpful assistant."},
                 %{"role" => "user", "content" => "Hi"}
               ] = decoded_body["messages"]

        Req.Test.json(conn, %{
          "model" => "llama3.2:latest",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"response": "Hello!"})
          },
          "done" => true,
          "done_reason" => "stop"
        })
      end)

      assert {:ok, _} = Ollama.call("Hi", [], config)
    end

    test "includes tools in API call" do
      config = %{
        model: "llama3.2:latest"
      }

      beam = TestBeam.view()

      Req.Test.expect(Ollama, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert [tool] = decoded_body["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "Lux_LLM_OllamaTest_TestBeam"

        # Should not set format: json when tools are present
        refute Map.has_key?(decoded_body, "format")

        Req.Test.json(conn, %{
          "model" => "llama3.2:latest",
          "message" => %{
            "role" => "assistant",
            "content" => ""
          },
          "done" => true,
          "done_reason" => "stop"
        })
      end)

      assert {:ok, _} = Ollama.call("test prompt", [beam], config)
    end

    test "handles tool call responses with successful tool execution" do
      config = %{
        model: "llama3.2:latest"
      }

      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "llama3.2:latest",
          "message" => %{
            "role" => "assistant",
            "content" => "",
            "tool_calls" => [
              %{
                "function" => %{
                  "name" => "#{TestPrism}",
                  "arguments" => %{"value" => "success"}
                }
              }
            ]
          },
          "done" => true,
          "done_reason" => "stop"
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  tool_calls: [
                    %{
                      "function" => %{
                        "arguments" => _args,
                        "name" => "Elixir.Lux.LLM.OllamaTest.TestPrism"
                      },
                      "type" => "function"
                    }
                  ],
                  tool_calls_results: [%{result: "success test"}]
                }
              }} = Ollama.call("test prompt", [TestPrism], config)
    end

    test "passes Ollama-specific options" do
      config = %{
        model: "llama3.2:latest",
        temperature: 0.5,
        num_ctx: 4096,
        num_gpu: 1,
        top_p: 0.9,
        top_k: 40,
        seed: 42,
        keep_alive: "10m"
      }

      Req.Test.expect(Ollama, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["options"]["temperature"] == 0.5
        assert decoded_body["options"]["num_ctx"] == 4096
        assert decoded_body["options"]["num_gpu"] == 1
        assert decoded_body["options"]["top_p"] == 0.9
        assert decoded_body["options"]["top_k"] == 40
        assert decoded_body["options"]["seed"] == 42
        assert decoded_body["keep_alive"] == "10m"

        Req.Test.json(conn, %{
          "model" => "llama3.2:latest",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"result": "ok"})
          },
          "done" => true,
          "done_reason" => "stop"
        })
      end)

      assert {:ok, _} = Ollama.call("test", [], config)
    end

    test "handles error responses" do
      config = %{
        model: "nonexistent:latest"
      }

      Req.Test.expect(Ollama, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "error" => "model 'nonexistent:latest' not found"
        }))
      end)

      assert {:error, {404, "model 'nonexistent:latest' not found"}} =
               Ollama.call("test", [], config)
    end

    test "handles connection refused (Ollama not running)" do
      config = %{
        model: "llama3.2:latest"
      }

      Req.Test.expect(Ollama, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, :ollama_not_running} = Ollama.call("test", [], config)
    end

    test "handles non-JSON text responses gracefully" do
      config = %{
        model: "llama3.2:latest",
        json_response: false
      }

      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "llama3.2:latest",
          "message" => %{
            "role" => "assistant",
            "content" => "Just plain text response"
          },
          "done" => true,
          "done_reason" => "stop"
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{
                  content: %{"text" => "Just plain text response"}
                }
              }} = Ollama.call("test", [], config)
    end

    test "calculates tokens per second in performance metadata" do
      config = %{model: "llama3.2:latest"}

      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "llama3.2:latest",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"result": "ok"})
          },
          "done" => true,
          "done_reason" => "stop",
          "eval_count" => 100,
          "eval_duration" => 2_000_000_000
        })
      end)

      assert {:ok,
              %Signal{
                metadata: %{
                  performance: %{
                    tokens_per_second: 50.0
                  }
                }
              }} = Ollama.call("test", [], config)
    end
  end

  describe "list_models/1" do
    test "returns list of available models" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/tags"

        Req.Test.json(conn, %{
          "models" => [
            %{
              "name" => "llama3.2:latest",
              "size" => 4_661_224_676,
              "digest" => "abc123",
              "modified_at" => "2024-01-01T00:00:00Z",
              "details" => %{
                "format" => "gguf",
                "family" => "llama",
                "parameter_size" => "8B"
              }
            },
            %{
              "name" => "codellama:7b",
              "size" => 3_825_819_519,
              "digest" => "def456",
              "modified_at" => "2024-01-02T00:00:00Z",
              "details" => %{
                "format" => "gguf",
                "family" => "llama",
                "parameter_size" => "7B"
              }
            }
          ]
        })
      end)

      assert {:ok, models} = Ollama.list_models()
      assert length(models) == 2
      assert Enum.any?(models, &(&1["name"] == "llama3.2:latest"))
      assert Enum.any?(models, &(&1["name"] == "codellama:7b"))
    end

    test "returns error when Ollama is not running" do
      Req.Test.stub(Ollama, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, :ollama_not_running} = Ollama.list_models()
    end
  end

  describe "pull_model/2" do
    test "successfully pulls a model" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/pull"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["name"] == "llama3.2:latest"
        assert decoded_body["stream"] == false

        Req.Test.json(conn, %{"status" => "success"})
      end)

      assert {:ok, %{"status" => "success"}} = Ollama.pull_model("llama3.2:latest")
    end

    test "returns error for invalid model" do
      Req.Test.expect(Ollama, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "error" => "pull model manifest: file does not exist"
        }))
      end)

      assert {:error, {404, "pull model manifest: file does not exist"}} =
               Ollama.pull_model("nonexistent:model")
    end
  end

  describe "show_model/2" do
    test "returns model information" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/show"

        Req.Test.json(conn, %{
          "modelfile" => "FROM llama3.2",
          "parameters" => "temperature 0.7",
          "template" => "{{ .System }}\n{{ .Prompt }}",
          "details" => %{
            "format" => "gguf",
            "family" => "llama",
            "parameter_size" => "8B",
            "quantization_level" => "Q4_0"
          }
        })
      end)

      assert {:ok, info} = Ollama.show_model("llama3.2:latest")
      assert info["details"]["family"] == "llama"
      assert info["details"]["parameter_size"] == "8B"
    end

    test "returns error for non-existent model" do
      Req.Test.expect(Ollama, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "error" => "model not found"
        }))
      end)

      assert {:error, :model_not_found} = Ollama.show_model("nonexistent:model")
    end
  end

  describe "delete_model/2" do
    test "successfully deletes a model" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/delete"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["name"] == "llama3.2:latest"

        Plug.Conn.send_resp(conn, 200, "")
      end)

      assert :ok = Ollama.delete_model("llama3.2:latest")
    end

    test "returns error for non-existent model" do
      Req.Test.expect(Ollama, fn conn ->
        Plug.Conn.send_resp(conn, 404, "")
      end)

      assert {:error, :model_not_found} = Ollama.delete_model("nonexistent:model")
    end
  end

  describe "health_check/1" do
    test "returns healthy when Ollama is running" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "GET"
        Plug.Conn.send_resp(conn, 200, "Ollama is running")
      end)

      assert {:ok, :healthy} = Ollama.health_check()
    end

    test "returns error when Ollama is not running" do
      Req.Test.stub(Ollama, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, :ollama_not_running} = Ollama.health_check()
    end
  end

  describe "ensure_model/2" do
    test "returns already_available when model exists" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.request_path == "/api/show"

        Req.Test.json(conn, %{
          "details" => %{"family" => "llama"}
        })
      end)

      assert {:ok, :already_available} = Ollama.ensure_model("llama3.2:latest")
    end

    test "pulls model when not found locally" do
      # First call - show_model returns 404
      Req.Test.expect(Ollama, fn conn ->
        assert conn.request_path == "/api/show"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "model not found"}))
      end)

      # Second call - pull_model succeeds
      Req.Test.expect(Ollama, fn conn ->
        assert conn.request_path == "/api/pull"

        Req.Test.json(conn, %{"status" => "success"})
      end)

      assert {:ok, :pulled} = Ollama.ensure_model("llama3.2:latest")
    end
  end

  describe "parse_content/1" do
    test "parses valid JSON" do
      assert {:ok, %{"key" => "value"}} = Ollama.parse_content(~s({"key": "value"}))
    end

    test "wraps non-JSON text" do
      assert {:ok, %{"text" => "plain text"}} = Ollama.parse_content("plain text")
    end

    test "handles nil" do
      assert {:ok, nil} = Ollama.parse_content(nil)
    end

    test "handles empty string" do
      assert {:ok, nil} = Ollama.parse_content("")
    end
  end
end
