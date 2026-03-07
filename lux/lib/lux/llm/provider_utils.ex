defmodule Lux.LLM.ProviderUtils do
  @moduledoc """
  Shared utilities for LLM providers.

  Extracts common functionality used across multiple providers to reduce
  code duplication and ensure consistent behavior.

  ## Features

  - Tool conversion (Beams, Prisms, Lenses → provider function format)
  - Tool execution
  - Content parsing (JSON responses)
  - Message building
  - Response handling
  """

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Logger

  # ─── Tool Conversion ──────────────────────────────────────────────────────

  @doc """
  Converts a tool (Beam, Prism, or Lens) to an OpenAI-compatible function definition.

  This format is used by OpenAI, Together AI, Ollama, and Mira, making it the
  de facto standard for tool definitions.

  ## Examples

      iex> ProviderUtils.tool_to_openai_function(MyPrism.view())
      %{type: "function", function: %{name: "MyPrism", description: "...", parameters: %{...}}}
  """
  @spec tool_to_openai_function(term()) :: map()
  def tool_to_openai_function({:python, path}) do
    path
    |> Prism.view()
    |> tool_to_openai_function()
  end

  def tool_to_openai_function(tool_module) when is_atom(tool_module) and not is_nil(tool_module) do
    cond do
      Lux.prism?(tool_module) -> tool_to_openai_function(tool_module.view())
      Lux.beam?(tool_module) -> tool_to_openai_function(tool_module.view())
      Lux.lens?(tool_module) -> tool_to_openai_function(tool_module.view())
      true -> raise "Unsupported tool type: #{inspect(tool_module)}"
    end
  end

  def tool_to_openai_function(%Beam{module_name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: sanitize_function_name(name),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  def tool_to_openai_function(%Prism{module_name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: sanitize_function_name(name),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  def tool_to_openai_function(%Lens{module_name: name, description: description, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: sanitize_function_name(name),
        description: description || "",
        parameters: schema
      }
    }
  end

  @doc """
  Converts a tool to Anthropic's tool format.

  Anthropic uses a slightly different format without the outer `type: "function"` wrapper.
  """
  @spec tool_to_anthropic_function(term()) :: map()
  def tool_to_anthropic_function(%Beam{} = beam) do
    %{
      name: beam.name,
      description: beam.description,
      input_schema: beam.input_schema
    }
  end

  def tool_to_anthropic_function(%Prism{} = prism) do
    %{
      name: prism.name,
      description: prism.description,
      input_schema: prism.input_schema
    }
  end

  def tool_to_anthropic_function(%Lens{} = lens) do
    %{
      name: lens.name,
      description: lens.description,
      input_schema: lens.params
    }
  end

  # ─── Tool Execution ──────────────────────────────────────────────────────

  @doc """
  Executes tool calls returned by an LLM.

  Handles the standard OpenAI format `[%{"function" => %{"name" => ..., "arguments" => ...}}]`.
  """
  @spec execute_tool_calls(list() | nil) :: {:ok, list() | nil} | {:error, term()}
  def execute_tool_calls(nil), do: {:ok, nil}

  def execute_tool_calls(tool_calls) when is_list(tool_calls) do
    tool_calls
    |> Enum.map(&execute_tool_call/1)
    |> Enum.reduce({:ok, []}, fn
      {:ok, result, _log}, {:ok, results} -> {:ok, [result | results]}
      {:ok, result}, {:ok, results} -> {:ok, [result | results]}
      error, _ -> error
    end)
  end

  @doc """
  Executes a single tool call.
  """
  @spec execute_tool_call(map()) :: {:ok, term()} | {:error, term()}
  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
    args = if is_binary(args), do: Jason.decode!(args), else: args
    execute_tool(tool_name, args)
  end

  @doc """
  Executes a tool by name with the given arguments.
  """
  @spec execute_tool(String.t() | atom(), map(), term()) :: {:ok, term()} | {:error, term()}
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
        {:error, "Failed to load tool module #{tool_name}: not implemented or reachable"}

      {:error, error} ->
        {:error, "Failed to load tool module #{tool_name}: #{inspect(error)}"}
    end
  end

  def execute_tool(tool_module, args, ctx) when is_atom(tool_module) do
    cond do
      Lux.prism?(tool_module) -> tool_module.handler(args, ctx)
      Lux.beam?(tool_module) -> tool_module.run(args, ctx)
      Lux.lens?(tool_module) -> tool_module.focus(args)
      true ->
        {:error, "Tool #{tool_module} is not a valid Beam, Prism, or Lens"}
    end
  end

  # ─── Content Parsing ─────────────────────────────────────────────────────

  @doc """
  Parses LLM response content, attempting JSON decode.

  Returns `{:ok, parsed}` for valid JSON, `{:error, reason}` for invalid JSON
  when strict mode is enabled, or `{:ok, raw_string}` in lenient mode.
  """
  @spec parse_json_content(String.t() | nil, keyword()) :: {:ok, term()} | {:error, String.t()}
  def parse_json_content(content, opts \\ [])

  def parse_json_content(nil, _opts), do: {:ok, nil}

  def parse_json_content(content, opts) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} ->
        {:ok, structured_output}

      {:error, _} ->
        if Keyword.get(opts, :strict, true) do
          {:error, "failed to parse content: #{inspect(content)}"}
        else
          {:ok, content}
        end
    end
  end

  @doc """
  Parses content leniently — returns raw string on JSON parse failure.
  """
  @spec parse_content_lenient(String.t() | nil) :: {:ok, term()}
  def parse_content_lenient(nil), do: {:ok, nil}

  def parse_content_lenient(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} -> {:ok, structured_output}
      {:error, _} -> {:ok, content}
    end
  end

  # ─── Message Building ───────────────────────────────────────────────────

  @doc """
  Builds a user message list from a prompt string.
  """
  @spec build_user_messages(String.t()) :: [map()]
  def build_user_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  @doc """
  Builds tools config list from a list of tool modules/structs.
  Returns empty list for empty input.
  """
  @spec build_tools_config([term()], atom()) :: [map()]
  def build_tools_config(tools, format \\ :openai)

  def build_tools_config([], _format), do: []

  def build_tools_config(tools, :openai) do
    Enum.map(tools, &tool_to_openai_function/1)
  end

  def build_tools_config(tools, :anthropic) do
    Enum.map(tools, &tool_to_anthropic_function/1)
  end

  # ─── Response Building ──────────────────────────────────────────────────

  @doc """
  Builds a standard ResponseSignal from an OpenAI-format response body.

  Used by OpenAI, Together AI, Ollama, and Mira providers.
  """
  @spec build_response_signal(map(), keyword()) ::
          {:ok, Lux.Signal.t()} | {:error, term()}
  def build_response_signal(body, opts \\ []) do
    parse_mode = Keyword.get(opts, :parse_mode, :strict)

    with %{"choices" => [choice | _]} <- body,
         %{"message" => message} <- choice,
         finish_reason <- choice["finish_reason"],
         {:ok, content} <- parse_content_by_mode(message["content"], parse_mode),
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

      %{
        schema_id: ResponseSignal,
        payload: payload,
        metadata: metadata
      }
      |> Lux.Signal.new()
      |> ResponseSignal.validate()
    end
  end

  # ─── Tool Choice Formatting ──────────────────────────────────────────────

  @doc """
  Formats tool_choice option for OpenAI-compatible APIs.
  """
  @spec format_tool_choice(term()) :: term()
  def format_tool_choice(:none), do: "none"
  def format_tool_choice(:auto), do: "auto"

  def format_tool_choice(name) when is_binary(name) do
    %{"type" => "function", "function" => %{"name" => sanitize_function_name(name)}}
  end

  def format_tool_choice(_), do: "auto"

  # ─── Helpers ─────────────────────────────────────────────────────────────

  @doc """
  Sanitizes a module/function name for use as an OpenAI function name.
  OpenAI function names must match [a-zA-Z0-9_-].
  """
  @spec sanitize_function_name(String.t()) :: String.t()
  def sanitize_function_name(name), do: String.replace(name, ".", "_")

  defp parse_content_by_mode(content, :strict), do: parse_json_content(content, strict: true)
  defp parse_content_by_mode(content, :lenient), do: parse_content_lenient(content)
end
