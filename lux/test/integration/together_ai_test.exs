defmodule Lux.Integration.LLM.TogetherAITest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.LLM.TogetherAI
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal
  alias Lux.SignalSchema

  describe "simple text request and response, no tools or structure output" do
    setup do
      config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_together],
        model: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
        temperature: 0.7
      }

      %{config: config}
    end

    test "it still returns a structured response", %{config: config} do
      assert {:ok,
              %Signal{
                id: _,
                metadata: %{
                  id: _,
                  usage: %{
                    "completion_tokens" => _,
                    "prompt_tokens" => _,
                    "total_tokens" => _
                  },
                  created: _,
                  system_fingerprint: _
                },
                payload: %{
                  model: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
                  content: %{"capital" => "Paris"},
                  tool_calls: nil,
                  tool_calls_results: nil,
                  finish_reason: "stop"
                },
                recipient: nil,
                schema_id: ResponseSignal,
                sender: nil,
                timestamp: _
              }} = TogetherAI.call("What is the capital of France?", [], config)
    end
  end

  describe "Requests with a response schema" do
    defmodule CapitalCitySchema do
      @moduledoc false
      use SignalSchema,
        schema: %{
          type: :object,
          properties: %{
            the_country: %{type: :string, description: "The country name"},
            the_capital: %{type: :string, description: "The capital city name"}
          },
          required: ["the_country", "the_capital"]
        }
    end

    test "will return a structured response according to the schema" do
      config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_together],
        model: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
        temperature: 0.7,
        json_schema: CapitalCitySchema
      }

      assert {:ok,
              %Signal{
                payload: %{
                  content: %{"the_capital" => "Paris", "the_country" => "France"} = content
                },
                schema_id: ResponseSignal
              }} = TogetherAI.call("What is the capital of France?", [], config)

      assert {:ok, _} = CapitalCitySchema.validate(Signal.new(%{payload: content}))
    end
  end

  describe "Requests with prisms and beams (tool calling)" do
    defmodule LoggingPrism do
      @moduledoc false
      use Lux.Prism,
        name: "#{__MODULE__}",
        id: __MODULE__,
        description: "Use this to print the input to the console",
        input_schema: %{type: "string"}

      require Logger

      def handler(input, _ctx) do
        Logger.info("LoggingPrism: #{inspect(input)}")
        {:ok, input}
      end
    end

    defmodule HashPrism do
      @moduledoc false
      use Lux.Prism,
        name: "#{HashPrism}",
        id: HashPrism,
        description: "Use this to hash a string",
        input_schema: %{
          type: "object",
          properties: %{
            value: %{type: "string", description: "The string to hash"},
            hashing_algorithm: %{
              type: "string",
              enum: ["sha256", "sha512"],
              description: "The hashing algorithm to use",
              default: "sha256"
            }
          },
          required: ["value", "algorithm"]
        },
        output_schema: %{
          type: "object",
          properties: %{
            hash: %{type: "string", description: "The hashed string"}
          },
          required: ["hash"]
        }

      def handler(%{value: value, algo: algo}, _ctx) do
        {:ok, %{hash: algo <> "_hashed_" <> value}}
      end

      def handler(%{"hashing_algorithm" => "sha256", "value" => "test"}, _) do
        {:ok, %{hash: "oooook"}}
      end
    end

    defmodule TestBeam do
      @moduledoc false
      use Lux.Beam,
        name: "#{__MODULE__}",
        id: TestBeam,
        description: "Use this when the user wants to hash a string",
        input_schema: %{
          type: "object",
          properties: %{
            to_hash: %{type: "string"},
            algorithm: %{type: "string", enum: ["sha256"]}
          },
          required: ["to_hash", "algorithm"]
        }

      sequence do
        step(:just_do_nothing, LoggingPrism, [:input])

        step(:hash, HashPrism, %{
          value: [:steps, :just_do_nothing, :result, "to_hash"],
          algo: [:input, "algorithm"]
        })
      end
    end

    test "will return a function call result in the response when calling a prism" do
      config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_together],
        model: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
        temperature: 0.7
      }

      assert {:ok,
              %Signal{
                payload: %{
                  content: nil,
                  tool_calls: [
                    %{
                      "function" => %{
                        "name" => "Elixir_Lux_Integration_LLM_TogetherAITest_HashPrism",
                        "arguments" => _
                      }
                    }
                  ],
                  tool_calls_results: [%{hash: "oooook"}],
                  finish_reason: "tool_calls"
                },
                schema_id: ResponseSignal
              }} =
               TogetherAI.call(
                 "Could you give me the hash of 'test' using sha256?",
                 [HashPrism],
                 config
               )
    end

    test "will return a function call result in the response when calling a beam" do
      config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_together],
        model: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
        temperature: 0.7
      }

      assert {:ok,
              %Signal{
                payload: %{
                  content: nil,
                  tool_calls: [
                    %{
                      "function" => %{
                        "name" => "Elixir_Lux_Integration_LLM_TogetherAITest_TestBeam",
                        "arguments" => _
                      }
                    }
                  ],
                  tool_calls_results: [%{hash: "sha256_hashed_SPECTRAL"}],
                  finish_reason: "tool_calls"
                },
                schema_id: ResponseSignal
              }} = TogetherAI.call("Could you help me to hash the word SPECTRAL?", [TestBeam], config)
    end
  end
end
