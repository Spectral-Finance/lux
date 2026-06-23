defmodule Lux.LLM.TogetherAI do
    @moduledoc """
    Together AI LLM implementation that supports passing Beams, Prisms, and Lenses as tools.
    """

    @behaviour Lux.LLM

    alias Lux.Beam
    alias Lux.Lens
    alias Lux.LLM.ResponseSignal
    alias Lux.Prism

    require Beam
    require Lens
    require Logger

    @endpoint "https://api.together.xyz/v1/chat/completions"

    defmodule Config do
      @moduledoc """
      Configuration module for Together AI.
      """
      @type t :: %__MODULE__{
              endpoint: String.t(),
              model: String.t(),
              api_key: String.t(),
              temperature: float(),
              top_p: float(),
              top_k: integer(),
              max_tokens: integer(),
              repetition_penalty: float(),
              stop: list(String.t()),
              user: String.t(),
              messages: [map()]
            }

      defstruct endpoint: "https://api.together.xyz/v1/chat/completions",
                model: "mistral-7b-instruct",
                api_key: nil,
                temperature: 0.7,
                top_p: 0.7,
                top_k: 50,
                max_tokens: nil,
                repetition_penalty: 1.0,
                stop: [],
                user: nil,
                messages: []
    end

    @impl true
    def call(prompt, tools, config) do
      config =
        struct(
          Config,
          Map.merge(
            %{
              model: Application.get_env(:lux, :together_ai_models)[:default],
              api_key: Application.get_env(:lux, :api_keys)[:together]
            },
            config
          )
        )

      messages = config.messages ++ build_messages(prompt)
      tools_config = build_tools_config(tools)

      body =
        %{
          model: Lux.Config.resolve(config.model),
          messages: messages,
          temperature: config.temperature,
          top_p: config.top_p,
          top_k: config.top_k,
          max_tokens: config.max_tokens,
          repetition_penalty: config.repetition_penalty,
          stop: config.stop
        }
        |> maybe_add_tools(tools_config)

      [
        url: config.endpoint || @endpoint,
        json: body,
        headers: [
          {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
          {"Content-Type", "application/json"}
        ]
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> Req.new()
      |> Req.post()
      |> case do
        {:ok, %{status: 200} = response} ->
          handle_response(response, config)

        {:ok, %{status: 401}} ->
          {:error, :invalid_api_key}

        {:ok, %{status: status, body: %{"error" => message}}} ->
          {:error, {status, message}}

        {:error, error} ->
          handle_error(error)
      end
    end

    defp build_messages(prompt) do
      [%{role: "user", content: prompt}]
    end

    defp build_tools_config([]), do: []
    defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

    defp maybe_add_tools(body, []), do: body
    defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

    def tool_to_function({:python, path}) do
      path
      |> Prism.view()
      |> tool_to_function()
    end

    def tool_to_function(tool_module) when is_atom(tool_module) and not is_nil(tool_module) do
      cond do
        Lux.prism?(tool_module) ->
          tool_to_function(tool_module.view())

        Lux.beam?(tool_module) ->
          tool_to_function(tool_module.view())

        Lux.lens?(tool_module) ->
          tool_to_function(tool_module.view())

        true ->
          raise "Unsupported tool type: #{inspect(tool_module)}"
      end
    end

    def tool_to_function(%Beam{} = beam) do
      name = (is_binary(beam.module_name) and beam.module_name != "" and beam.module_name) || 
             (is_binary(beam.name) and beam.name != "" and beam.name) || 
             "unnamed_beam"

      %{
        type: "function",
        function: %{
          name: String.replace(name, ".", "_"),
          description: beam.description || "",
          parameters: beam.input_schema
        }
      }
    end

    def tool_to_function(%Prism{} = prism) do
      name = (is_binary(prism.module_name) and prism.module_name != "" and prism.module_name) || 
             (is_binary(prism.name) and prism.name != "" and prism.name) || 
             "unnamed_prism"

      %{
        type: "function",
        function: %{
          name: String.replace(name, ".", "_"),
          description: prism.description || "",
          parameters: prism.input_schema
        }
      }
    end

    def tool_to_function(%Lens{} = lens) do
      name = (is_binary(lens.module_name) and lens.module_name != "" and lens.module_name) || 
             (is_binary(lens.name) and lens.name != "" and lens.name) || 
             "unnamed_lens"

      %{
        type: "function",
        function: %{
          name: String.replace(name, ".", "_"),
          description: lens.description || "",
          parameters: lens.schema
        }
      }
    end

    defp handle_response(%{body: body}, _config) do
      with %{"choices" => [choice | _]} <- body,
           %{"message" => message} <- choice,
           {:ok, content} <- parse_content(message["content"]),
           {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
        payload = %{
          content: content,
          model: body["model"],
          finish_reason: choice["finish_reason"],
          tool_calls: message["tool_calls"],
          tool_calls_results: tool_calls_results
        }

        metadata = %{
          id: body["id"],
          created: body["created"],
          usage: body["usage"],
          system_fingerprint: body["system_fingerprint"]
        }

        %{
          schema_id: ResponseSignal,
          payload: payload,
          metadata: metadata
        }
        |> Lux.Signal.new()
        |> ResponseSignal.validate()
      end
    end

    def parse_content(content) when is_binary(content) do
      case Jason.decode(content) do
        {:ok, structured_output} -> {:ok, structured_output}
        {:error, _} -> {:ok, %{"text" => content}}
      end
    end

    def parse_content(_), do: {:ok, nil}

    def execute_tool_calls(tool_calls) when is_list(tool_calls) do
      tool_calls
      |> Enum.map(&execute_tool_call/1)
      |> Enum.reduce({:ok, []}, fn
        {:ok, result, _log}, {:ok, results} -> {:ok, [result | results]}
        {:ok, result}, {:ok, results} -> {:ok, [result | results]}
        error, _ -> error
      end)
    end

    def execute_tool_calls(nil), do: {:ok, nil}

    def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
      case Jason.decode(args) do
        {:ok, parsed_args} -> execute_tool(tool_name, parsed_args, nil)
        {:error, error} -> {:error, "Failed to parse tool arguments: #{inspect(error)}"}
      end
    end

    def execute_tool(tool_name, args, ctx) when is_binary(tool_name) do
      tool_name
      |> String.replace("_", ".")
      |> List.wrap()
      |> Module.concat()
      |> Code.ensure_loaded()
      |> case do
        {:module, module_name} ->
          execute_tool(module_name, args, ctx)

        {:error, :nofile} ->
          {:error, "Failed to load tool module #{tool_name}: It doesn't seems to be implemented or reacheable"}

        {:error, error} ->
          {:error, "Failed to load tool module #{tool_name}: #{inspect(error)}"}
      end
    end

    def execute_tool(tool_module, args, ctx) when is_atom(tool_module) do
      cond do
        Lux.prism?(tool_module) ->
          tool_module.handler(args, ctx)

        Lux.beam?(tool_module) ->
          tool_module.run(args, ctx)

        Lux.lens?(tool_module) ->
          tool_module.focus(args)

        true ->
          {:error, """
          Tool #{tool_module} does not seem to be a valid Beam, Prism, or Lens
          as it does not have a registered `handler`, `run` or `focus` function.
          """}
      end
    end

    defp handle_error(error) do
      Logger.error("Together AI API error: #{inspect(error)}")
      {:error, "Together AI API error: #{inspect(error)}"}
    end
end
