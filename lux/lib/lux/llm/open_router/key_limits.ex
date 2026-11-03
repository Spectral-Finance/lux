defmodule Lux.LLM.OpenRouter.KeyLimits do
  @moduledoc """
  Module for querying OpenRouter API key information, rate limits, credit balance, and usage statistics.

  OpenRouter exposes the `/api/v1/auth/key` endpoint which provides details about the current API key:
  - `label`: Friendly label of the key
  - `usage`: Total USD spent across all models
  - `limit`: Credit limit in USD (nil if unlimited)
  - `is_free_tier`: Whether the account is currently on free tier
  - `rate_limit`: Requests per interval limits
  """

  require Logger

  @endpoint "https://openrouter.ai/api/v1/auth/key"

  defmodule Info do
    @moduledoc """
    Structured representation of OpenRouter API key limits and status.
    """
    @type t :: %__MODULE__{
            label: String.t() | nil,
            usage: float(),
            limit: float() | nil,
            credits_remaining: float() | :unlimited,
            usage_percentage: float() | nil,
            is_free_tier: boolean(),
            rate_limit_requests: integer() | nil,
            rate_limit_interval: String.t() | nil,
            raw: map()
          }

    defstruct [
      :label,
      :limit,
      usage: 0.0,
      credits_remaining: :unlimited,
      usage_percentage: nil,
      is_free_tier: false,
      rate_limit_requests: nil,
      rate_limit_interval: nil,
      raw: %{}
    ]
  end

  @doc """
  Fetches key information for the given API key or default configured key.
  """
  @spec get_key_info(String.t() | nil, keyword()) :: {:ok, Info.t()} | {:error, term()}
  def get_key_info(api_key \\ nil, opts \\ []) do
    key = api_key || get_configured_api_key()

    if is_nil(key) or key == "" or key == "missing openrouter" do
      {:error, :missing_api_key}
    else
      headers = [
        {"Authorization", "Bearer #{key}"},
        {"Content-Type", "application/json"}
      ]

      endpoint = Keyword.get(opts, :endpoint, @endpoint)

      [
        url: endpoint,
        headers: headers
      ]
      |> Keyword.merge(opts)
      |> Req.new()
      |> Req.get()
      |> handle_response()
    end
  end

  @doc """
  Checks if the API key has sufficient remaining credits for an estimated cost.
  """
  @spec has_sufficient_credits?(Info.t(), float()) :: boolean()
  def has_sufficient_credits?(%Info{credits_remaining: :unlimited}, _estimated_cost), do: true
  def has_sufficient_credits?(%Info{credits_remaining: rem}, estimated_cost) when is_number(rem) do
    rem >= estimated_cost
  end

  defp handle_response({:ok, %{status: 200, body: %{"data" => data}}}) do
    usage = to_float(data["usage"] || 0.0)
    limit = if is_number(data["limit"]), do: to_float(data["limit"]), else: nil

    credits_remaining =
      case limit do
        nil -> :unlimited
        l when is_number(l) -> max(0.0, Float.round(l - usage, 6))
      end

    usage_percentage =
      case limit do
        nil -> nil
        0.0 -> 100.0
        l when is_number(l) and l > 0 -> Float.round((usage / l) * 100.0, 2)
      end

    rate_limit = data["rate_limit"] || %{}

    info = %Info{
      label: data["label"],
      usage: usage,
      limit: limit,
      credits_remaining: credits_remaining,
      usage_percentage: usage_percentage,
      is_free_tier: data["is_free_tier"] || false,
      rate_limit_requests: rate_limit["requests"],
      rate_limit_interval: rate_limit["interval"],
      raw: data
    }

    {:ok, info}
  end

  defp handle_response({:ok, %{status: 401}}) do
    {:error, :invalid_api_key}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.warning("OpenRouter key limits check returned status #{status}: #{inspect(body)}")
    {:error, {status, body}}
  end

  defp handle_response({:error, reason}) do
    Logger.error("Failed to query OpenRouter key limits: #{inspect(reason)}")
    {:error, reason}
  end

  defp to_float(val) when is_float(val), do: val
  defp to_float(val) when is_integer(val), do: val * 1.0
  defp to_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end
  defp to_float(_), do: 0.0

  defp get_configured_api_key do
    case Application.get_env(:lux, :api_keys) do
      keys when is_list(keys) -> Keyword.get(keys, :openrouter)
      keys when is_map(keys) -> Map.get(keys, :openrouter)
      _ -> nil
    end || System.get_env("OPENROUTER_API_KEY")
  end
end
