 ```diff
--- /dev/null
+++ b/lux/lib/lux/llm/ollama.ex
@@ -0,0 +1,296 @@
+defmodule Lux.LLM.Ollama do
+  @moduledoc """
+  Ollama API client for local LLM support.
+  
+  Provides integration with Ollama for running local models,
+  including model management, caching, and resource controls.
+  """
+  
+  require Logger
+  
+  alias Lux.LLM.Ollama.Model
+  
+  @default_base_url "http://localhost:11434"
+  @default_timeout 300_000
+  @default_max_tokens 2048
+  @default_temperature 0.7
+  
+  @type t :: %__MODULE__{
+    base_url: String.t(),
+    model: String.t(),
+    temperature: float(),
+    max_tokens: integer(),
+    timeout: integer(),
+    stream: boolean()
+  }
+  
+  defstruct [
+    :base_url,
+    :model,
+    :temperature,
+    :max_tokens,
+    :timeout,
+    :stream
+  ]
+  
+  @doc """
+  Creates a new Ollama client configuration.
+  
+  ## Options
+  
+    * `:base_url` - Ollama API base URL (default: http://localhost:11434)
+    * `:model` - Model name to use (required)
+    * `:temperature` - Sampling temperature (default: 0.7)
+    * `:max_tokens` - Maximum tokens to generate (default: 2048)
+    * `:timeout` - Request timeout in milliseconds (default: 300000)
+    * `:stream` - Whether to stream responses (default: false)
+  
+  ## Examples
+  
+      iex> Lux.LLM.Ollama.new(model: "llama2")
+      %Lux.LLM.Ollama{model: "llama2", ...}
+  """
+  @spec new(keyword()) :: t()
+  def new(opts \\ []) do
+    %__MODULE__{
+      base_url: Keyword.get(opts, :base_url, default_base_url()),
+      model: Keyword.fetch!(opts, :model),
+      temperature: Keyword.get(opts, :temperature, @default_temperature),
+      max_tokens: Keyword.get(opts, :max_tokens, @default_max_tokens),
+      timeout: Keyword.get(opts, :timeout, @default_timeout),
+      stream: Keyword.get(opts, :stream, false)
+    }
+  end
+  
+  @doc """
+  Returns the default Ollama base URL.
+  """
+  @spec default_base_url() :: String.t()
+  def default_base_url, do: @default_base_url
+  
+  @doc """
+  Generates a completion using the configured model.
+  
+  ## Options
+  
+    * `:prompt` - The prompt text (required)
+    * `:system` - Optional system message
+    * `:options` - Additional Ollama options
+  
+  ## Examples
+  
+      iex> client = Lux.LLM.Ollama.new(model: "llama2")
+      iex> Lux.LLM.Ollama.complete(client, prompt: "Hello, world!")
+      {:ok, %{response: "..."}}
+  """
+  @spec complete(t(), keyword()) :: {:ok, map()} | {:error, term()}
+  def complete(%__MODULE__{} = client, opts) do
+    prompt = Keyword.fetch!(opts, :prompt)
+    system = Keyword.get(opts, :system)
+    options = Keyword.get(opts, :options, %{})
+    
+    body = build_request_body(client, prompt, system, options)
+    
+    case post(client, "/api/generate", body) do
+      {:ok, response} ->
+        {:ok, parse_response(response)}
+        
+      {:error, reason} ->
+        {:error, reason}
+    end
+  end
+  
+  @doc """
+  Generates a chat completion using the configured model.
+  
+  ## Options
+  
+    * `:messages` - List of messages with `:role` and `:content` (required)
+    * `:options` - Additional Ollama options
+  
+  ## Examples
+  
+      iex> client = Lux.LLM.Ollama.new(model: "llama2")
+      iex> messages = [%{role: "user", content: "Hello!"}]
+      iex> Lux.LLM.Ollama.chat(client, messages: messages)
+      {:ok, %{message: %{role: "assistant", content: "..."}}}
+  """
+  @spec chat(t(), keyword()) :: {:ok, map()} | {:error, term()}
+  def chat(%__MODULE__{} = client, opts) do
+    messages = Keyword.fetch!(opts, :messages)
+    options = Keyword.get(opts, :options, %{})
+    
+    body = %{
+      model: client.model,
+      messages: format_messages(messages),
+      stream: false,
+      options: build_options(client, options)
+    }
+    
+    case post(client, "/api/chat", body) do
+      {:ok, response} ->
+        {:ok, parse_chat_response(response)}
+        
+      {:error, reason} ->
+        {:error, reason}
+    end
+  end
+  
+  @doc """
+  Streams a completion response.
+  
+  The callback function receives each chunk as it arrives.
+  """
+  @spec stream_complete(t(), keyword(), (map() -> any())) :: {:ok, map()} | {:error, term()}
+  def stream_complete(%__MODULE__{} = client, opts, callback) when is_function(callback, 1) do
+    prompt = Keyword.fetch!(opts, :prompt)
+    system = Keyword.get(opts, :system)
+    options = Keyword.get(opts, :options, %{})
+    
+    body = build_request_body(client, prompt, system, options)
+    |> Map.put(:stream, true)
+    
+    stream_post(client, "/api/generate", body, callback)
+  end
+  
+  @doc """
+  Checks if Ollama server is available.
+  """
+  @spec available?(t() | nil) :: boolean()
+  def available?(client \\ nil) do
+    base_url = if client, do: client.base_url, else: default_base_url()
+    
+    case HTTPoison.get("#{base_url}/api/tags", [], timeout: 5000) do
+      {:ok, %{status_code: 200}} -> true
+      _ -> false
+    end
+  end
+  
+