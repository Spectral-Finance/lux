defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama local LLM implementation that supports passing Beams, Prisms, and Lenses as tools.
  Enables self-hosted inference with zero API keys and local privacy.
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @default_endpoint "http://localhost:11434/api/chat"

  defmodule Config do
    @moduledoc """
    Configuration module for Ollama.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            base_url: String.t(),
            model: String.t(),
            temperature: float(),
            top_p: float(),
            top_k: integer(),
            stream: boolean(),
            format: String.t() | map() | nil,
            receive_timeout: integer(),
            seed: integer() | nil,
            num_ctx: integer() | nil,
            num_predict: integer() | nil,
            repeat_penalty: float(),
            messages: [map()]
          }

    defstruct endpoint: "http://localhost:11434/api/chat",
              base_url: "http://localhost:11434",
              model: "llama3.2",
              temperature: 0.7,
              top_p: 0.9,
              top_k: 40,
              stream: false,
              format: nil,
              receive_timeout: 120_000,
              seed: nil,
              num_ctx: nil,
              num_predict: nil,
              repeat_penalty: 1.1,
              messages: []
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :ollama_models, [default: "llama3.2"])[:default] || "llama3.2",
            base_url: Application.get_env(:lux, :ollama_base_url, "http://localhost:11434"),
            endpoint: Application.get_env(:lux, :ollama_endpoint, @default_endpoint)
          },
          config
        )
      )

    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    options =
      %{
        temperature: config.temperature,
        top_p: config.top_p,
        top_k: config.top_k,
        repeat_penalty: config.repeat_penalty
      }
      |> maybe_put(:seed, config.seed)
      |> maybe_put(:num_ctx, config.num_ctx)
      |> maybe_put(:num_predict, config.num_predict)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        stream: false,
        options: options
      }
      |> maybe_add_format(config.format)
      |> maybe_add_tools(tools_config)

    [
      url: config.endpoint,
      json: body,
      receive_timeout: config.receive_timeout,
      headers: [
        {"Content-Type", "application/json"}
      ]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: 404, body: %{"error" => "model '" <> _ = message}}} ->
        {:error, {:model_not_found, message}}

      {:ok, %{status: status, body: %{"error" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  List locally downloaded models from the Ollama instance.
  """
  def list_models(config \\ %Config{}) do
    base_url = Map.get(config, :base_url, "http://localhost:11434")
    url = "#{base_url}/api/tags"

    [url: url]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        {:ok, models}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, "Failed to connect to Ollama at #{url}: #{inspect(error)}"}
    end
  end

  @doc """
  Pull a model to the local Ollama instance.
  """
  def pull_model(model_name, config \\ %Config{}) do
    base_url = Map.get(config, :base_url, "http://localhost:11434")
    url = "#{base_url}/api/pull"

    [
      url: url,
      json: %{name: model_name, stream: false},
      receive_timeout: Map.get(config, :receive_timeout, 600_000)
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200, body: %{"status" => "success"} = res}} ->
        {:ok, res}

      {:ok, %{status: 200, body: res}} ->
        {:ok, res}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, "Failed to pull model #{model_name}: #{inspect(error)}"}
    end
  end

  @doc """
  Delete a model from the local Ollama instance.
  """
  def delete_model(model_name, config \\ %Config{}) do
    base_url = Map.get(config, :base_url, "http://localhost:11434")
    url = "#{base_url}/api/delete"

    [
      url: url,
      json: %{name: model_name}
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.delete()
    |> case do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, "Failed to delete model #{model_name}: #{inspect(error)}"}
    end
  end

  @doc """
  Show details of a local model.
  """
  def show_model(model_name, config \\ %Config{}) do
    base_url = Map.get(config, :base_url, "http://localhost:11434")
    url = "#{base_url}/api/show"

    [
      url: url,
      json: %{name: model_name}
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
        {:error, "Failed to show model #{model_name}: #{inspect(error)}"}
    end
  end

  defp build_messages(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  defp maybe_add_format(body, nil), do: body
  defp maybe_add_format(body, format), do: Map.put(body, :format, format)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

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
        %{
          type: "function",
          function: %{
            name: String.replace(to_string(tool_module), ".", "_"),
            description: "",
            parameters: %{type: "object", properties: %{}}
          }
        }
    end
  end

  def tool_to_function(%Beam{name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  def tool_to_function(%Prism{module_name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  def tool_to_function(%Lens{name: name, description: description, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: name || "unnamed_lens",
        description: description || "",
        parameters: schema
      }
    }
  end

  defp handle_response(%{body: body}, _config) do
    message = body["message"] || %{}
    content = message["content"]
    tool_calls = message["tool_calls"]
    finish_reason = body["done_reason"] || if(body["done"], do: "stop", else: nil)

    with {:ok, parsed_content} <- parse_content(content),
         {:ok, tool_calls_results} <- execute_tool_calls(tool_calls) do
      payload = %{
        content: parsed_content,
        model: body["model"],
        finish_reason: finish_reason,
        tool_calls: tool_calls,
        tool_calls_results: tool_calls_results
      }

      metadata = %{
        created_at: body["created_at"],
        total_duration: body["total_duration"],
        load_duration: body["load_duration"],
        prompt_eval_count: body["prompt_eval_count"],
        eval_count: body["eval_count"]
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
      {:ok, structured_output} ->
        {:ok, structured_output}

      {:error, _} ->
        {:ok, content}
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

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) when is_map(args) do
    execute_tool(tool_name, args, nil)
  end

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) when is_binary(args) do
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
        {:error, "Failed to load tool module #{tool_name}: It doesn't seem to be implemented or reachable"}

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
        {:error, "Tool #{tool_module} does not seem to be a valid Beam, Prism or Lens"}
    end
  end

  defp handle_error(error) do
    Logger.error("Ollama API error: #{inspect(error)}")
    {:error, "Ollama API error: #{inspect(error)}"}
  end
end
