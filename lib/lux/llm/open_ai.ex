defmodule Lux.LLM.OpenAI do
  @moduledoc """
  OpenAI LLM implementation that supports passing Beams, Prisms, and Lenses as tools.
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Prism
  alias Lux.Lens
  alias Lux.LLM.Response

  require Logger
  require Beam
  require Prism
  require Lens

  @endpoint "https://api.openai.com/v1/chat/completions"

  defmodule Config do
    @moduledoc """
    Configuration module for OpenAI.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            frequency_penalty: float(),
            reasoning_mode: boolean(),
            reasoning_effort: String.t(),
            receive_timeout: integer(),
            seed: integer(),
            n: integer(),
            json_response: boolean(),
            json_schema: map(),
            max_tokens: integer(),
            tool_choice: map(),
            user: String.t(),
            messages: [map()]
          }

    defstruct endpoint: "https://api.openai.com/v1/chat/completions",
              model: "gpt-4",
              api_key: nil,
              temperature: 0.7,
              frequency_penalty: 0.0,
              reasoning_mode: false,
              reasoning_effort: "medium",
              receive_timeout: 60_000,
              seed: nil,
              n: 1,
              json_response: true,
              json_schema: nil,
              max_tokens: nil,
              tool_choice: nil,
              user: nil,
              messages: []
  end

  @impl true
  def call(prompt, tools, %Config{} = config) do
    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    body =
      %{
        model: config.model,
        messages: messages,
        temperature: config.temperature,
        frequency_penalty: config.frequency_penalty,
        max_tokens: config.max_tokens
      }
      |> maybe_add_tools(tools_config, config.tool_choice)
      |> maybe_add_response_format(config)

    [
      url: @endpoint,
      json: body,
      headers: [
        {"Authorization", "Bearer #{config.api_key}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} -> handle_response(response, config)
      {:error, error} -> handle_error(error)
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
    do: %{"type" => "function", "function" => %{"name" => name |> String.replace(".", "_")}}

  defp format_tool_choice(_), do: "auto"

  defp maybe_add_response_format(body, %Config{json_response: false}) do
    Map.put(body, :response_format, %{type: "text"})
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: schema})
       when is_map(schema) do
    Map.put(body, :response_format, %{
      type: "json_schema",
      json_schema: schema
    })
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: nil}) do
    %{
      body
      | messages:
          Enum.map(body.messages, &%{&1 | content: &1.content <> "\n Reply in json format"})
    }
    |> Map.put(:response_format, %{type: "json_object"})
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: schema})
       when is_atom(schema) do
    Map.put(body, :response_format, %{
      type: "json_schema",
      json_schema: %{name: schema.name, schema: schema.schema}
    })
  end

  defp maybe_add_response_format(body, _), do: Map.put(body, :response_format, %{type: "text"})

  def tool_to_function(tool_module) when is_atom(tool_module) and not is_nil(tool_module) do
    tool_to_function(tool_module.view())
  end

  def tool_to_function(%Beam{name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: name || "unnamed_beam",
        description: description || "",
        parameters: input_schema
      }
    }
  end

  def tool_to_function(%Prism{name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        # OpenAI function names must be [a-zA-Z0-9_-]
        name: name |> String.replace(".", "_"),
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

  defp handle_response(%{body: body}, config) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message, "finish_reason" => finish_reason} <- choice,
         {:ok, content} <- parse_content(message["content"]),
         {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
      payload = %{
        content: content,
        model: body["model"],
        finish_reason: finish_reason,
        tool_calls: message["tool_calls"],
        tool_calls_results: tool_calls_results
      }

      metadata = %{
        id: body["id"],
        created: body["created"],
        usage: body["usage"],
        system_fingerprint: body["system_fingerprint"]
      }

      Lux.Signal.new(%{
        schema_id: Lux.LLM.ResponseSignal,
        payload: payload,
        metadata: metadata
      })
      |> Lux.LLM.ResponseSignal.validate()
    else
      error ->
        {:error, "Invalid response format from OpenAI"}
    end
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
      {:ok, result}, {:ok, results} -> {:ok, [result | results]}
      error, _ -> error
    end)
  end

  def execute_tool_calls(nil), do: {:ok, nil}

  def execute_tool_call(%{"function" => %{"name" => name, "arguments" => args}}) do
    args = Jason.decode!(args)

    module =
      name
      # Names sent to OpenAI function must follow [a-zA-Z0-9_-],
      # so we revert back to the original name...
      |> String.replace("_", ".")
      |> List.wrap()
      |> Module.concat()

    with {_, ^module} <- {:module, Code.ensure_loaded!(module)},
         {_, true} <- {:check_handler, function_exported?(module, :handler, 2)},
         {:ok, result} <- module.handler(args, nil) do
      {:ok, result}
    else
      {:check_handler, false} ->
        {:error, "Tool #{module} does not have a registered handler"}

      error ->
        {:error, "Tool #{module} execution failed: #{inspect(error)}"}
    end
  end

  defp format_tool_call(%{
         "function" => %{"arguments" => args, "name" => name},
         "id" => id,
         "type" => type
       }) do
    %{
      type: type,
      # OpenAI function names must be [a-zA-Z0-9_-]...
      name: name |> String.replace(".", "_"),
      call_id: id,
      params: Jason.decode!(args)
    }
  end

  defp handle_error(%{"error" => %{"message" => message, "type" => type}}) do
    Logger.error("OpenAI API error: #{type} - #{message}")
    {:error, "OpenAI API error: #{type} - #{message}"}
  end

  defp handle_error(error) do
    Logger.error("OpenAI API error: #{inspect(error)}")
    {:error, "OpenAI API error: #{inspect(error)}"}
  end

  defp schema_to_properties(nil), do: %{}
  defp schema_to_properties(%{} = schema) when map_size(schema) == 0, do: %{}

  defp schema_to_properties(%{type: "object", properties: properties}) do
    properties
  end

  defp schema_to_properties(schema) when is_list(schema) do
    schema
    |> Enum.map(fn {key, opts} ->
      {Atom.to_string(key),
       %{
         type: Atom.to_string(opts[:type] || :string),
         description: opts[:description] || ""
       }}
    end)
    |> Enum.into(%{})
  end

  defp resolve_schema(schema) when is_atom(schema) do
    if function_exported?(schema, :schema, 0) do
      schema.schema()
    else
      schema
    end
  end

  defp resolve_schema(schema), do: schema
end
