defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation that supports passing Beams, Prisms, and Lenses as tools.
  Connects to a local or remote Ollama instance via its REST API.
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism
  require Logger

  @endpoint "http://localhost:11434/api/chat"

  defmodule Config do
    @moduledoc """
    Configuration module for Ollama.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            temperature: float(),
            num_ctx: integer(),
            keep_alive: String.t(),
            receive_timeout: integer(),
            seed: integer(),
            json_response: boolean(),
            max_tokens: integer(),
            top_p: float(),
            top_k: integer(),
            tool_choice: map(),
            user: String.t(),
            messages: [map()]
          }

    defstruct endpoint: "http://localhost:11434/api/chat",
              model: "llama3",
              temperature: 0.7,
              num_ctx: 4096,
              keep_alive: "5m",
              receive_timeout: 120_000,
              seed: nil,
              json_response: true,
              max_tokens: nil,
              top_p: 0.9,
              top_k: 40,
              tool_choice: nil,
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
            model: Application.get_env(:lux, :ollama_models, %{})[:default] || "llama3"
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
        stream: false,
        options: %{
          temperature: config.temperature,
          top_p: config.top_p,
          top_k: config.top_k,
          num_ctx: config.num_ctx
        },
        keep_alive: config.keep_alive
      }
      |> maybe_add_tools(tools_config, config.tool_choice)
      |> maybe_add_response_format(config)
      |> maybe_add_seed(config.seed)

    [
      url: config.endpoint || @endpoint,
      json: body,
      headers: [
        {"Content-Type", "application/json"}
      ],
      receive_timeout: config.receive_timeout
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: status, body: %{"error" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} when is_binary(body) ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  defp build_messages(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, [], _tool_choice), do: body

  defp maybe_add_tools(body, tools, tool_choice) do
    body
    |> Map.put(:tools, tools)
    |> Map.put(:tool_choice, format_tool_choice(tool_choice))
  end

  defp format_tool_choice(:none), do: "none"
  defp format_tool_choice(:auto), do: "auto"

  defp format_tool_choice(name) when is_binary(name),
    do: %{"type" => "function", "function" => %{"name" => String.replace(name, ".", "_")}}

  defp format_tool_choice(_), do: "auto"

  defp maybe_add_response_format(body, %Config{json_response: true}) do
    Map.put(body, :format, "json")
  end

  defp maybe_add_response_format(body, _config), do: body

  defp maybe_add_seed(body, nil), do: body

  defp maybe_add_seed(body, seed) do
    update_in(body, [:options], &Map.put(&1, :seed, seed))
  end

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

  def tool_to_function(%Beam{
        module_name: name,
        description: description,
        input_schema: input_schema
      }) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  def tool_to_function(%Prism{
        module_name: name,
        description: description,
        input_schema: input_schema
      }) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  def tool_to_function(%Lens{module_name: name, description: description, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: schema
      }
    }
  end

  defp handle_response(%{body: body}, _config) do
    with %{"message" => message} <- body,
         finish_reason <- if(body["done"], do: "stop", else: "length"),
         {:ok, content} <- parse_content(message["content"]),
         {:ok, tool_calls_results} <-
           execute_tool_calls(convert_tool_calls(message["tool_calls"])) do
      tool_calls = convert_tool_calls_for_response(message["tool_calls"])

      payload = %{
        content: content,
        model: body["model"],
        finish_reason: finish_reason,
        tool_calls: tool_calls,
        tool_calls_results: tool_calls_results
      }

      metadata = %{
        id: body["created_at"],
        created: body["created_at"],
        usage: build_usage(body),
        system_fingerprint: nil
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

  defp build_usage(body) do
    %{
      "prompt_tokens" => body["prompt_eval_count"],
      "completion_tokens" => body["eval_count"],
      "total_tokens" => (body["prompt_eval_count"] || 0) + (body["eval_count"] || 0)
    }
  end

  # Ollama returns tool_calls as a list of %{"function" => %{"name" => ..., "arguments" => ...}}
  # We need to convert arguments from a map to a JSON string for compatibility with OpenAI's format
  defp convert_tool_calls(nil), do: nil

  defp convert_tool_calls(tool_calls) when is_list(tool_calls) do
    Enum.map(tool_calls, fn
      %{"function" => %{"name" => name, "arguments" => args}} when is_map(args) ->
        %{
          "type" => "function",
          "function" => %{"name" => name, "arguments" => Jason.encode!(args)}
        }

      %{"function" => %{"name" => name, "arguments" => args}} when is_binary(args) ->
        %{"type" => "function", "function" => %{"name" => name, "arguments" => args}}

      other ->
        other
    end)
  end

  defp convert_tool_calls_for_response(nil), do: nil

  defp convert_tool_calls_for_response(tool_calls) when is_list(tool_calls) do
    Enum.map(tool_calls, fn
      %{"function" => %{"name" => name, "arguments" => args}} when is_map(args) ->
        %{
          "type" => "function",
          "function" => %{"name" => name, "arguments" => Jason.encode!(args)}
        }

      %{"function" => %{"name" => name, "arguments" => args}} when is_binary(args) ->
        %{"type" => "function", "function" => %{"name" => name, "arguments" => args}}

      other ->
        other
    end)
  end

  def parse_content("") do
    {:ok, nil}
  end

  def parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} ->
        {:ok, structured_output}

      {:error, _} ->
        {:error, "failed to parse content: #{inspect(content)}"}
    end
  end

  def parse_content(_), do: {:ok, nil}

  def execute_tool_calls(tool_calls) when is_list(tool_calls) do
    tool_calls
    |> Enum.map(&execute_tool_call/1)
    |> Enum.reduce({:ok, []}, fn
      {:ok, result, _log}, {:ok, results} ->
        {:ok, [result | results]}

      {:ok, result}, {:ok, results} ->
        {:ok, [result | results]}

      error, _ ->
        error
    end)
  end

  def execute_tool_calls(nil), do: {:ok, nil}

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
    args = Jason.decode!(args)
    execute_tool(tool_name, args, nil)
  end

  def execute_tool(tool_name, args, ctx \\ nil)

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
        {:error,
         "Failed to load tool module #{tool_name}: It doesn't seems to be implemented or reacheable"}

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
        {:error,
         """
         Tool #{tool_module} does not seem to be a valid Beam or Prism
         as it does not have a registered `handler` or `run` function.
         """}
    end
  end

  # Model management functions

  @doc """
  Lists all models available on the Ollama instance.
  """
  def list_models(opts \\ []) do
    base_url = Keyword.get(opts, :base_url, "http://localhost:11434")

    [
      url: "#{base_url}/api/tags",
      headers: [{"Content-Type", "application/json"}]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        {:ok, models}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Pulls a model from the Ollama library.
  """
  def pull_model(model_name, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, "http://localhost:11434")

    [
      url: "#{base_url}/api/pull",
      json: %{name: model_name, stream: false},
      headers: [{"Content-Type", "application/json"}],
      receive_timeout: 600_000
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Shows information about a model.
  """
  def show_model(model_name, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, "http://localhost:11434")

    [
      url: "#{base_url}/api/show",
      json: %{name: model_name},
      headers: [{"Content-Type", "application/json"}]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Deletes a model from the Ollama instance.
  """
  def delete_model(model_name, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, "http://localhost:11434")

    [
      url: "#{base_url}/api/delete",
      json: %{name: model_name},
      headers: [{"Content-Type", "application/json"}]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request(method: :delete)
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  defp handle_error(error) do
    Logger.error("Ollama API error: #{inspect(error)}")
    {:error, "Ollama API error: #{inspect(error)}"}
  end
end
