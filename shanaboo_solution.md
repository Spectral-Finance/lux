 ```diff
--- /dev/null
+++ b/lux/lib/lux/llm/perplexity.ex
@@ -0,0 +1,268 @@
+defmodule Lux.LLM.Perplexity do
+  @moduledoc """
+  Perplexity AI integration for Lux.
+
+  Provides access to Perplexity's language models with support for:
+  - Streaming and non-streaming responses
+  - Model selection
+  - Cost tracking
+  - Error handling
+
+  ## Configuration
+
+  Configure the Perplexity client in your config:
+
+      config :lux, :perplexity,
+        api_key: System.get_env("PERPLEXITY_API_KEY"),
+        default_model: "sonar",
+        base_url: "https://api.perplexity.ai"
+
+  ## Usage
+
+      iex> alias Lux.LLM.Perplexity
+      iex> Perplexity.chat_completion([%{role: "user", content: "Hello!"}])
+      {:ok, %Lux.LLM.Perplexity.Response{}}
+
+  """
+
+  alias Lux.LLM.Perplexity.CostTracker
+
+  @default_base_url "https://api.perplexity.ai"
+  @default_model "sonar"
+
+  @valid_models [
+    "sonar",
+    "sonar-pro",
+    "sonar-reasoning",
+    "sonar-deep-research",
+    "sonar-reasoning-pro"
+  ]
+
+  @type message :: %{
+          role: String.t(),
+          content: String.t()
+        }
+
+  @type chat_opts :: %{
+          optional(:model) => String.t(),
+          optional(:temperature) => float(),
+          optional(:max_tokens) => integer(),
+          optional(:top_p) => float(),
+          optional(:stream) => boolean(),
+          optional(:presence_penalty) => float(),
+          optional(:frequency_penalty) => float()
+        }
+
+  @doc """
+  Returns the list of available Perplexity models.
+  """
+  @spec available_models() :: [String.t()]
+  def available_models, do: @valid_models
+
+  @doc """
+  Sends a chat completion request to Perplexity AI.
+
+Chat completion request to Perplexity AI.
+
+  ## Options
+
+  - `:model` - Model to use (default: "sonar")
+  - `:temperature` - Sampling temperature (0.0 to 2.0)
+  - `:max_tokens` - Maximum tokens to generate
+  - `:top_p` - Nucleus sampling parameter
+  - `:stream` - Enable streaming (default: false)
+  - `:presence_penalty` - Presence penalty (-2.0 to 2.0)
+  - `:frequency_penalty` - Frequency penalty (-2.0 to 2.0)
+
+  ## Examples
+
+      iex> Perplexity.chat_completion([%{role: "user", content: "What is Elixir?"}])
+      {:ok, %Lux.LLM.Perplexity.Response{}}
+
+  """
+  @spec chat_completion([message()], keyword()) ::
+          {:ok, Lux.LLM.Perplexity.Response.t()} | {:error, term()}
+  def chat_completion(messages, opts \\ []) do
+    config = get_config()
+    model = Keyword.get(opts, :model, config[:default_model] || @default_model)
+
+    unless model in @valid_models do
+      return_error(:invalid_model, "Invalid model: #{model}")
+    end
+
+    body = build_request_body(messages, model, opts)
+
+    if Keyword.get(opts, :stream, false) do
+      stream_chat_completion(body, config, opts)
+    else
+      do_chat_completion(body, config, opts)
+    end
+  end
+
+  @doc """
+  Streams a chat completion response from Perplexity AI.
+
+  The callback function receives chunks of the response as they arrive.
+
+  ## Examples
+
+      iex> Perplexity.stream_chat_completion([%{role: "user", content: "Hello!"}], fn chunk ->
+      ...>   IO.puts(chunk.content)
+      ...> end)
+      {:ok, %Lux.LLM.Perplexity.Response{}}
+
+  """
+  @spec stream_chat_completion([message()], (term() -> term()), keyword()) ::
+          {:ok, Lux.LLM.Perplexity.Response.t()} | {:error, term()}
+  def stream_chat_completion(messages, callback \\ nil, opts \\ [])
+
+  def stream_chat_completion(messages, callback, opts) when is_function(callback, 1) do
+    config = get_config()
+    model = Keyword.get(opts, :model, config[:default_model] || @default_model)
+    body = build_request_body(messages, model, Keyword.put(opts, :stream, true))
+
+    do_stream_chat_completion(body, config, callback, opts)
+  end
+
+  def stream_chat_completion(messages, opts, []) when is_list(opts) do
+    # Handle case where opts is passed as third arg
+    stream_chat_completion(messages, nil, opts)
+  end
+
+  def stream_chat_completion(messages, nil, opts) do
+    config = get_config()
+    model = Keyword.get(opts, :model, config[:default_model] || @default_model)
+    body = build_request_body(messages, model, Keyword.put(opts, :stream, true))
+
+    do_stream_chat_completion(body, config, nil, opts)
+  end
+
+  # Private functions
+
+  defp get_config do
+    Application.get_env(:lux, :perplexity, [])
+    |> Keyword.put_new(:base_url, @default_base_url)
+    |> Keyword.put_new(:default_model, @default_model)
+  end
+
+  defp build_request_body(messages, model, opts) do
+    %{
+      model: model,
+      messages: messages
+    }
+    |> maybe_put(:temperature, Keyword.get(opts, :temperature))
+    |> maybe_put(:max_tokens, Keyword.get(opts, :max_tokens))
+    |> maybe_put(:top_p, Keyword.get(opts, :top_p))
+    |> maybe_put(:stream, Keyword.get(opts, :stream, false))
+    |> maybe_put(:presence_penalty, Keyword.get(opts, :presence_penalty))
+    |> maybe_put(:frequency_penalty, Keyword.get(opts, :frequency_penalty))
+  end
+
+  defp maybe_put(map, _key, nil), do: map
+  defp maybe_put(map, key, value), do: Map.put(map, key, value)
+
+  defp do_chat_completion(body, config, opts) do
+    api_key = get_api