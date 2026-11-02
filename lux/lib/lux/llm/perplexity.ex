defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI LLM provider integration for Lux.
  Provides access to online, citations-grounded models (Sonar, Sonar Pro, Sonar Reasoning)
  with search domain filtering, recency controls, and cost tracking.

  Resolves Spectral-Finance/lux#97 ($300 Bounty: Perplexity AI Integration).
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @endpoint "https://api.perplexity.ai/chat/completions"

  defmodule Config do
    @moduledoc """
    Configuration struct for Perplexity AI provider.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t() | nil,
            temperature: float(),
            top_p: float(),
            max_tokens: integer() | nil,
            search_domain_filter: list(String.t()),
            search_recency_filter: String.t() | nil,
            return_citations: boolean(),
            return_images: boolean(),
            return_related_questions: boolean(),
            receive_timeout: integer(),
            messages: [map()]
          }

    defstruct endpoint: "https://api.perplexity.ai/chat/completions",
              model: "sonar",
              api_key: nil,
              temperature: 0.2,
              top_p: 0.9,
              max_tokens: nil,
              search_domain_filter: [],
              search_recency_filter: nil,
              return_citations: true,
              return_images: false,
              return_related_questions: false,
              receive_timeout: 60_000,
              messages: []
  end

  @impl true
  def call(prompt, tools, config) when is_map(config) or is_list(config) do
    config_map = if is_list(config), do: Map.new(config), else: config

    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :perplexity_models)[:default] || "sonar",
            api_key: Application.get_env(:lux, :api_keys)[:perplexity]
          },
          config_map
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
        return_citations: config.return_citations,
        return_images: config.return_images,
        return_related_questions: config.return_related_questions
      }
      |> maybe_add_max_tokens(config.max_tokens)
      |> maybe_add_search_domain_filter(config.search_domain_filter)
      |> maybe_add_search_recency_filter(config.search_recency_filter)
      |> maybe_add_tools(tools_config)

    headers = [
      {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
      {"Content-Type", "application/json"}
    ]

    [
      url: config.endpoint || @endpoint,
      json: body,
      headers: headers,
      receive_timeout: config.receive_timeout
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  defp build_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_messages(messages) when is_list(messages), do: messages

  defp build_tools_config([]), do: []
  defp build_tools_config(tools) when is_list(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_max_tokens(body, nil), do: body
  defp maybe_add_max_tokens(body, max_tokens), do: Map.put(body, :max_tokens, max_tokens)

  defp maybe_add_search_domain_filter(body, []), do: body
  defp maybe_add_search_domain_filter(body, domains) when is_list(domains) and length(domains) > 0 do
    Map.put(body, :search_domain_filter, domains)
  end

  defp maybe_add_search_recency_filter(body, nil), do: body
  defp maybe_add_search_recency_filter(body, recency) when is_binary(recency) do
    Map.put(body, :search_recency_filter, recency)
  end

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools) do
    Map.put(body, :tools, tools)
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

  def tool_to_function(%Beam{module_name: name, description: description, input_schema: input_schema}) do
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
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message} <- choice,
         finish_reason <- Map.get(choice, "finish_reason"),
         {:ok, content} <- parse_content(message["content"]) do
      
      citations = Map.get(body, "citations", [])

      payload = %{
        content: content,
        model: body["model"],
        finish_reason: finish_reason,
        citations: citations,
        tool_calls: message["tool_calls"]
      }

      metadata = %{
        id: body["id"],
        created: body["created"],
        usage: body["usage"],
        citations_count: length(citations)
      }

      %{
        payload: payload,
        metadata: metadata
      }
      |> ResponseSignal.new()
    else
      error ->
        {:error, "Failed to parse Perplexity AI response: #{inspect(error)}"}
    end
  end

  def parse_content(content) when is_binary(content), do: {:ok, content}
  def parse_content(nil), do: {:ok, nil}
  def parse_content(other), do: {:ok, inspect(other)}

  defp handle_error(error) do
    Logger.error("Perplexity AI API error: #{inspect(error)}")
    {:error, "Perplexity AI API error: #{inspect(error)}"}
  end
end
