defmodule Lux.LLM.OllamaTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Ollama
  alias Lux.LLM.Ollama.Models
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

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "Models" do
    test "list/0 returns available models" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/tags"

        Req.Test.json(conn, %{
          "models" => [
            %{"name" => "llama3.2", "size" => 2_000_000_000, "modified_at" => "2024-01-01"},
            %{"name" => "mistral:7b", "size" => 4_100_000_000, "modified_at" => "2024-01-02"}
          ]
        })
      end)

      assert {:ok,
              [
                %{"name" => "llama3.2", "size" => 2_000_000_000},
                %{"name" => "mistral:7b", "size" => 4_100_000_000}
              ]} = Models.list("http://localhost:11434")
    end

    test "list/0 with no explicit endpoint uses default_endpoint/0" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "GET"
        # default_endpoint returns "http://localhost:11434" from app config
        Req.Test.json(conn, %{"models" => []})
      end)

      assert {:ok, []} = Models.list()
    end

    test "pull/2 downloads a model" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/pull"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["name"] == "llama3.2"
        assert decoded["stream"] == false

        Req.Test.json(conn, %{"status" => "success"})
      end)

      assert {:ok, %{"status" => "success"}} = Models.pull("llama3.2", "http://localhost:11434")
    end

    test "delete/2 removes a model" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/delete"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["name"] == "mistral:7b"

        Req.Test.json(conn, %{})
      end)

      assert :ok = Models.delete("mistral:7b", "http://localhost:11434")
    end

    test "show/2 returns model info" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/show"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["name"] == "llama3.2"

        Req.Test.json(conn, %{
          "modelfile" => "FROM llama3.2",
          "parameters" => "num_ctx 4096",
          "template" => "{{ .Prompt }}",
          "details" => %{
            "parent_model" => "",
            "format" => "gguf",
            "family" => "llama",
            "families" => ["llama"],
            "parameter_size" => "3.2B",
            "quantization_level" => "Q4_0"
          }
        })
      end)

      assert {:ok, %{"details" => %{"parameter_size" => "3.2B", "family" => "llama"}}} =
               Models.show("llama3.2", "http://localhost:11434")
    end

    test "running?/1 checks if Ollama is available" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "GET"
        Req.Test.json(conn, %{"status" => "ok"})
      end)

      assert :ok = Models.running?("http://localhost:11434")
    end

    test "running?/0 with no explicit endpoint uses default_endpoint/0" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "GET"
        Req.Test.json(conn, %{"status" => "ok"})
      end)

      assert :ok = Models.running?()
    end

    @tag :skip
    test "running?/1 returns error when not running" do
      Req.Test.expect(Ollama, fn conn ->
        conn
        |> Plug.Conn.send_resp(503, Jason.encode!(%{"error" => "not running"}))
      end)

      assert {:error, {:not_running, 503}} = Models.running?("http://localhost:11434")
    end

    test "default_endpoint/0 returns configured endpoint when valid string" do
      original = Application.get_env(:lux, :ollama_endpoint)
      Application.put_env(:lux, :ollama_endpoint, "http://my-server:11434")

      try do
        assert "http://my-server:11434" = Models.default_endpoint()
      after
        Application.put_env(:lux, :ollama_endpoint, original)
      end
    end

    test "default_endpoint/0 falls back to default when endpoint is nil" do
      original = Application.get_env(:lux, :ollama_endpoint)
      Application.delete_env(:lux, :ollama_endpoint)

      try do
        assert "http://localhost:11434" = Models.default_endpoint()
      after
        Application.put_env(:lux, :ollama_endpoint, original)
      end
    end

    test "default_endpoint/0 falls back to default when endpoint is misconfigured (non-string)" do
      original = Application.get_env(:lux, :ollama_endpoint)
      # Simulate keyword-list misconfiguration
      Application.put_env(:lux, :ollama_endpoint, default: "http://localhost:11434")

      try do
        assert "http://localhost:11434" = Models.default_endpoint()
      after
        Application.put_env(:lux, :ollama_endpoint, original)
      end
    end
  end

  describe "tool_to_function/1" do
    test "converts a beam to an Ollama function" do
      beam =
        Lux.Beam.new(
          name: "TestBeam",
          description: "A test beam",
          input_schema: %{
            type: "object",
            properties: %{
              "value" => %{
                type: "string",
                description: "Test value"
              },
              "amount" => %{
                type: "float",
                description: "Test amount"
              }
            }
          }
        )

      function = Ollama.tool_to_function(beam)

      assert %{
               type: "function",
               function: %{
                 name: "TestBeam",
                 description: "A test beam",
                 parameters: %{
                   type: "object",
                   properties: %{
                     "value" => %{type: "string", description: "Test value"},
                     "amount" => %{type: "float", description: "Test amount"}
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
                   type: :object,
                   properties: %{value: %{type: :string}}
                 }
               }
             } = function
    end

    test "converts a lens to an Ollama function" do
      lens =
        Lux.Lens.new(
          name: "WeatherAPI",
          module_name: "WeatherAPI",
          description: "Gets weather data",
          schema: %{
            type: "object",
            properties: %{
              location: %{type: "string", description: "City name"},
              units: %{type: "string", description: "Temperature units"}
            }
          }
        )

      function = Ollama.tool_to_function(lens)

      assert %{
               type: "function",
               function: %{
                 name: "WeatherAPI",
                 description: "Gets weather data",
                 parameters: %{
                   type: "object",
                   properties: %{
                     location: %{type: "string", description: "City name"},
                     units: %{type: "string", description: "Temperature units"}
                   }
                 }
               }
             } = function
    end
  end

  describe "call/3" do
    test "makes correct API call with tools" do
      config = %{
        api_key: nil,
        model: "llama3.2"
      }

      beam =
        Lux.Beam.new(
          name: "TestBeam",
          description: "A test beam",
          input_schema: %{
            type: "object",
            properties: %{
              "value" => %{type: "string", description: "Test value"}
            }
          }
        )

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        # No auth header when api_key is nil
        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert [] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "llama3.2"
        assert [%{"role" => "user", "content" => "test prompt"}] = decoded_body["messages"]
        assert decoded_body["stream"] == false

        # Tools should be present
        assert [tool] = decoded_body["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "TestBeam"

        # Options with Ollama-specific params
        options = decoded_body["options"]
        assert is_float(options["temperature"])
        assert is_float(options["top_p"])
        assert is_integer(options["top_k"])
        assert is_float(options["repeat_penalty"])
        assert is_integer(options["num_ctx"])

        # Ollama format: top-level message with JSON content
        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"result": "Test response"}),
            "done" => true
          },
          "done" => true,
          "prompt_eval_count" => 15,
          "eval_count" => 42
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"result" => "Test response"},
                  finish_reason: "stop",
                  model: "llama3.2",
                  tool_calls: nil,
                  tool_calls_results: nil
                },
                metadata: %{
                  usage: %{
                    prompt_tokens: 15,
                    completion_tokens: 42
                  }
                }
              }} = Ollama.call("test prompt", [beam], config)
    end

    test "handles plain text response (FIX-2: no format: json)" do
      config = %{
        api_key: nil,
        model: "llama3.2"
      }

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        # Ollama returns plain text string in content when format is nil
        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{
            "role" => "assistant",
            "content" => "This is a plain text response from the model.",
            "done" => true
          },
          "done" => true,
          "prompt_eval_count" => 10,
          "eval_count" => 25
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{
                  content: %{"text" => "This is a plain text response from the model."},
                  finish_reason: "stop"
                }
              }} = Ollama.call("test prompt", [], config)
    end

    test "handles tool call responses with successful tool call (prism)" do
      config = %{
        api_key: nil,
        model: "llama3.2"
      }

      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{
            "role" => "assistant",
            "tool_calls" => [
              %{
                "function" => %{
                  "name" => "Lux_LLM_OllamaTest_TestPrism",
                  "arguments" => ~s({"value": "success"})
                }
              }
            ],
            "done" => true
          },
          "done" => true
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: nil,
                  model: "llama3.2",
                  tool_calls: [
                    %{
                      "function" => %{
                        "arguments" => ~s({"value": "success"}),
                        "name" => "Lux_LLM_OllamaTest_TestPrism"
                      }
                    }
                  ],
                  tool_calls_results: [%{result: "success test"}]
                }
              }} = Ollama.call("test prompt", [TestPrism], config)
    end

    test "handles tool call with map arguments (FIX-3: already decoded)" do
      config = %{
        api_key: nil,
        model: "llama3.2"
      }

      Req.Test.expect(Ollama, fn conn ->
        # Ollama may return arguments as a map instead of JSON string
        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{
            "role" => "assistant",
            "tool_calls" => [
              %{
                "function" => %{
                  "name" => "Lux_LLM_OllamaTest_TestPrism",
                  "arguments" => %{"value" => "success"}
                }
              }
            ],
            "done" => true
          },
          "done" => true
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{
                  tool_calls_results: [%{result: "success test"}]
                }
              }} = Ollama.call("test prompt", [TestPrism], config)
    end

    test "includes Ollama-specific options in the request" do
      config = %{
        api_key: "test_key",
        model: "mistral:7b",
        temperature: 0.8,
        top_p: 0.95,
        top_k: 20,
        num_ctx: 8192,
        num_predict: 512,
        repeat_penalty: 1.2,
        stop: ["END"],
        keep_alive: "10m"
      }

      Req.Test.expect(Ollama, fn conn ->
        # Auth header present when api_key is set
        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test_key"] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        options = decoded_body["options"]
        assert options["temperature"] == 0.8
        assert options["top_p"] == 0.95
        assert options["top_k"] == 20
        assert options["num_ctx"] == 8192
        assert options["num_predict"] == 512
        assert options["repeat_penalty"] == 1.2
        assert options["stop"] == ["END"]

        # keep_alive
        assert decoded_body["keep_alive"] == "10m"

        Req.Test.json(conn, %{
          "model" => "mistral:7b",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"result": "Test"}),
            "done" => true
          },
          "done" => true
        })
      end)

      assert {:ok, _} = Ollama.call("test prompt", [], config)
    end

    test "handles system prompt" do
      config = %{
        api_key: nil,
        model: "llama3.2",
        system: "You are a helpful assistant."
      }

      Req.Test.expect(Ollama, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        messages = decoded_body["messages"]
        assert [%{"role" => "system", "content" => "You are a helpful assistant."} | _] = messages

        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"result": "ok"}),
            "done" => true
          },
          "done" => true
        })
      end)

      assert {:ok, _} = Ollama.call("test prompt", [], config)
    end

    test "handles json format option" do
      config = %{
        api_key: nil,
        model: "llama3.2",
        format: "json"
      }

      Req.Test.expect(Ollama, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["format"] == "json"

        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"structured": true}),
            "done" => true
          },
          "done" => true
        })
      end)

      assert {:ok, _} = Ollama.call("test prompt", [], config)
    end

    test "returns error when Ollama is not running" do
      config = %{
        api_key: nil,
        model: "llama3.2"
      }

      Req.Test.expect(Ollama, fn conn ->
        conn
        |> Plug.Conn.send_resp(503, Jason.encode!(%{"error" => "Ollama is not running"}))
      end)

      assert {:error, :ollama_not_running} = Ollama.call("test prompt", [], config)
    end

    test "returns error when model is not found" do
      config = %{
        api_key: nil,
        model: "nonexistent-model"
      }

      Req.Test.expect(Ollama, fn conn ->
        conn
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "model not found"}))
      end)

      assert {:error, :model_not_found} = Ollama.call("test prompt", [], config)
    end

    test "returns error with api_key set" do
      config = %{
        api_key: "secret_key",
        model: "llama3.2"
      }

      Req.Test.expect(Ollama, fn conn ->
        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer secret_key"] = auth_header

        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"result": "auth test"}),
            "done" => true
          },
          "done" => true
        })
      end)

      assert {:ok, _} = Ollama.call("test prompt", [], config)
    end

    test "handles nil content in response" do
      config = %{
        api_key: nil,
        model: "llama3.2"
      }

      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{
            "role" => "assistant",
            "content" => nil,
            "done" => true
          },
          "done" => true
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{content: nil}
              }} = Ollama.call("test prompt", [], config)
    end

    test "handles OpenAI-compatible proxy format" do
      config = %{
        api_key: nil,
        model: "llama3.2"
      }

      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "id" => "chatcmpl-123",
          "object" => "chat.completion",
          "created" => 1_700_000_000,
          "model" => "llama3.2",
          "choices" => [
            %{
              "index" => 0,
              "message" => %{
                "role" => "assistant",
                "content" => "Plain text proxy response"
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{
            "prompt_tokens" => 10,
            "completion_tokens" => 20,
            "total_tokens" => 30
          }
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{
                  content: %{"text" => "Plain text proxy response"},
                  finish_reason: "stop"
                },
                metadata: %{
                  id: "chatcmpl-123",
                  usage: %{
                    "prompt_tokens" => 10,
                    "completion_tokens" => 20,
                    "total_tokens" => 30
                  }
                }
              }} = Ollama.call("test prompt", [], config)
    end
  end

  describe "embed/2" do
    test "generates embedding for a single input" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/embed"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["model"] == "nomic-embed-text"
        assert decoded["input"] == "Hello world"
        assert decoded["stream"] == false

        Req.Test.json(conn, %{
          "model" => "nomic-embed-text",
          "embeddings" => [
            [0.1, 0.2, 0.3, 0.4, 0.5]
          ],
          "prompt_eval_count" => 5
        })
      end)

      assert {:ok, %{"embeddings" => [[0.1, 0.2, 0.3, 0.4, 0.5]]}} =
               Ollama.embed("Hello world",
                 model: "nomic-embed-text",
                 endpoint: "http://localhost:11434"
               )
    end

    test "generates embeddings for batch inputs" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/embed"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["input"] == ["Hello", "World"]

        Req.Test.json(conn, %{
          "model" => "nomic-embed-text",
          "embeddings" => [
            [0.1, 0.2, 0.3],
            [0.4, 0.5, 0.6]
          ]
        })
      end)

      assert {:ok, %{"embeddings" => [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]]}} =
               Ollama.embed(["Hello", "World"],
                 model: "nomic-embed-text",
                 endpoint: "http://localhost:11434"
               )
    end

    test "handles embedding API errors" do
      Req.Test.expect(Ollama, fn conn ->
        conn
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "model not found"}))
      end)

      assert {:error, {:http_error, 500, _body}} =
               Ollama.embed("test", model: "nonexistent", endpoint: "http://localhost:11434")
    end

    test "uses config endpoint when endpoint option not provided" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        # The embed function strips /api/chat from the config endpoint
        # Config default is http://localhost:11434/api/chat → http://localhost:11434
        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "embeddings" => [[0.1, 0.2]]
        })
      end)

      assert {:ok, %{"embeddings" => [[0.1, 0.2]]}} =
               Ollama.embed("test", model: "llama3.2")
    end
  end

  describe "parse_content/1" do
    test "parses JSON content" do
      assert {:ok, %{"key" => "value"}} = Ollama.parse_content(~s({"key": "value"}))
    end

    test "wraps plain text in a map (FIX-2: no crash on non-JSON)" do
      assert {:ok, %{"text" => "Hello world"}} = Ollama.parse_content("Hello world")
    end

    test "handles nil content" do
      assert {:ok, nil} = Ollama.parse_content(nil)
    end

    test "handles empty string" do
      assert {:ok, %{"text" => ""}} = Ollama.parse_content("")
    end

    test "parses complex nested JSON" do
      json = ~s({"items": [{"name": "a"}, {"name": "b"}], "count": 2})

      assert {:ok, %{"items" => [%{"name" => "a"}, %{"name" => "b"}], "count" => 2}} =
               Ollama.parse_content(json)
    end
  end
end
