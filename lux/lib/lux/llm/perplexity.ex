defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI LLM integration for Lux (`https://api.perplexity.ai/chat/completions`).

  Supports:
  - Specialized Sonar models (`sonar`, `sonar-pro`, `sonar-reasoning`, `sonar-reasoning-pro`, `sonar-deep-research`)
  - Search domain filters, recency filters, and citation extraction
  - Server-Sent Events (SSE) response streaming parser
  - Token & search-request cost tracking and optimization
  """

  @endpoint "https://api.perplexity.ai/chat/completions"

  @model_pricing %{
    "sonar" => %{input_per_1m: 1.00, output_per_1m: 1.00, search_fee_per_1k: 5.00},
    "sonar-pro" => %{input_per_1m: 3.00, output_per_1m: 15.00, search_fee_per_1k: 5.00},
    "sonar-reasoning" => %{input_per_1m: 1.00, output_per_1m: 5.00, search_fee_per_1k: 5.00},
    "sonar-reasoning-pro" => %{input_per_1m: 2.00, output_per_1m: 8.00, search_fee_per_1k: 5.00},
    "sonar-deep-research" => %{input_per_1m: 2.00, output_per_1m: 8.00, search_fee_per_1k: 5.00}
  }

  defmodule Config do
    @moduledoc "Configuration for Perplexity AI requests."
    defstruct api_key: nil,
              model: "sonar-pro",
              temperature: 0.2,
              max_tokens: 2048,
              search_domain_filter: [],
              search_recency_filter: nil,
              return_citations: true,
              stream: false
  end

  @doc """
  Selects the optimal Perplexity Sonar model for a given task complexity and budget constraint.
  """
  @spec select_model(atom(), keyword()) :: String.t()
  def select_model(task_type, opts \\ []) do
    max_cost_tier = Keyword.get(opts, :max_cost_tier, :high)

    case {task_type, max_cost_tier} do
      {:deep_research, _} -> "sonar-deep-research"
      {:reasoning, :low} -> "sonar-reasoning"
      {:reasoning, _} -> "sonar-reasoning-pro"
      {:knowledge_intensive, :low} -> "sonar"
      {:knowledge_intensive, _} -> "sonar-pro"
      _ -> "sonar"
    end
  end

  @doc """
  Builds a validated Perplexity `/chat/completions` request payload.
  """
  @spec build_payload(String.t() | [map()], %Config{}) :: {:ok, map()} | {:error, atom()}
  def build_payload(prompt_or_messages, %Config{} = config) do
    cond do
      not Map.has_key?(@model_pricing, config.model) ->
        {:error, :unsupported_model}

      is_binary(prompt_or_messages) and String.trim(prompt_or_messages) == "" ->
        {:error, :empty_prompt}

      true ->
        messages =
          if is_binary(prompt_or_messages) do
            [%{role: "user", content: prompt_or_messages}]
          else
            prompt_or_messages
          end

        base = %{
          model: config.model,
          messages: messages,
          temperature: config.temperature,
          max_tokens: config.max_tokens,
          return_citations: config.return_citations,
          stream: config.stream
        }

        base =
          if is_list(config.search_domain_filter) and config.search_domain_filter != [] do
            Map.put(base, :search_domain_filter, config.search_domain_filter)
          else
            base
          end

        base =
          if config.search_recency_filter in ["month", "week", "day", "hour"] do
            Map.put(base, :search_recency_filter, config.search_recency_filter)
          else
            base
          end

        {:ok, base}
    end
  end

  @doc """
  Parses an SSE stream chunk buffer from Perplexity into structured deltas and citations.
  """
  @spec parse_sse_stream(String.t()) :: {:ok, %{content: String.t(), citations: [String.t()], chunks: non_neg_integer()}}
  def parse_sse_stream(raw_sse) when is_binary(raw_sse) do
    lines =
      raw_sse
      |> String.split(~r/\r?\n/, trim: true)
      |> Enum.filter(&String.starts_with?(&1, "data: "))
      |> Enum.map(&String.replace_prefix(&1, "data: ", ""))
      |> Enum.reject(&(&1 == "[DONE]"))

    {texts, citations, count} =
      Enum.reduce(lines, {[], [], 0}, fn line, {acc_text, acc_cit, cnt} ->
        case Jason.decode(line) do
          {:ok, decoded} ->
            delta = get_in(decoded, ["choices", Access.at(0), "delta", "content"]) || ""
            cits = Map.get(decoded, "citations", [])
            {[delta | acc_text], acc_cit ++ cits, cnt + 1}

          _ ->
            {acc_text, acc_cit, cnt}
        end
      end)

    {:ok,
     %{
       content: texts |> Enum.reverse() |> Enum.join(""),
       citations: Enum.uniq(citations),
       chunks: count
     }}
  end

  @doc """
  Calculates exact USD cost for a Perplexity completion including input/output tokens and search fee.
  """
  @spec estimate_cost(String.t(), non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          {:ok, %{total_usd: float(), token_cost_usd: float(), search_cost_usd: float()}}
          | {:error, :unsupported_model}
  def estimate_cost(model, prompt_tokens, completion_tokens, search_requests \\ 1) do
    case Map.fetch(@model_pricing, model) do
      {:ok, rates} ->
        token_cost =
          prompt_tokens / 1_000_000 * rates.input_per_1m +
            completion_tokens / 1_000_000 * rates.output_per_1m

        search_cost = search_requests / 1_000 * rates.search_fee_per_1k
        total = Float.round(token_cost + search_cost, 6)

        {:ok,
         %{
           total_usd: total,
           token_cost_usd: Float.round(token_cost, 6),
           search_cost_usd: Float.round(search_cost, 6)
         }}

      :error ->
        {:error, :unsupported_model}
    end
  end

  @doc "Returns the canonical Perplexity API endpoint."
  def endpoint, do: @endpoint
end
