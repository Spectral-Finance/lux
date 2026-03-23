defmodule Lux.Lenses.Telegram.BotMetrics do
  @moduledoc """
  A lens for reading Telegram bot metrics from the analytics collector.

  Fetches current bot statistics and returns a formatted metrics summary
  suitable for monitoring dashboards and reporting.

  ## Usage

      iex> BotMetrics.focus(%{format: "summary"})
      {:ok, %{messages: %{total: 150, ...}, commands: %{total: 50, ...}, ...}}

      iex> BotMetrics.focus(%{format: "json"})
      {:ok, %{"messages" => %{"total" => 150, ...}, ...}}
  """

  use Lux.Lens,
    name: "Telegram Bot Metrics",
    description: "Reads current Telegram bot analytics metrics",
    url: "local://telegram/bot_metrics",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        format: %{
          type: :string,
          description: "Output format: summary, json, or ascii",
          enum: ["summary", "json", "ascii"],
          default: "summary"
        }
      },
      required: []
    }

  alias Lux.Integrations.Telegram.Analytics.{Collector, Formatter}
  require Logger

  @doc """
  Fetches and formats bot metrics before the lens focuses.

  Overrides the default HTTP-based lens behavior to read from
  the local analytics collector instead.
  """
  @impl true
  def before_focus(params) do
    %{params: params, url: "local://telegram/bot_metrics"}
  end

  @doc """
  Processes the collected metrics and returns formatted output.

  This callback intercepts the normal lens pipeline since we're
  reading from local ETS tables rather than an external API.
  """
  @impl true
  def after_focus(_response) do
    try do
      stats = Collector.get_stats()
      format = "summary"

      result = case format do
        "json" -> Formatter.to_json(stats)
        "ascii" -> %{report: Formatter.to_ascii_table(stats)}
        _ -> Formatter.to_summary(stats)
      end

      {:ok, result}
    rescue
      e ->
        Logger.error("Failed to fetch bot metrics: #{inspect(e)}")
        {:error, "Failed to fetch bot metrics: #{Exception.message(e)}"}
    end
  end

  @doc """
  Direct access to bot metrics without going through the lens pipeline.

  ## Parameters

    * `format` - Output format: `:summary`, `:json`, or `:ascii`

  ## Returns

  Formatted metrics in the requested format.
  """
  @spec get_metrics(atom()) :: {:ok, map() | String.t()} | {:error, term()}
  def get_metrics(format \\ :summary) do
    try do
      stats = Collector.get_stats()

      result = case format do
        :json -> Formatter.to_json(stats)
        :ascii -> Formatter.to_ascii_table(stats)
        _ -> Formatter.to_summary(stats)
      end

      {:ok, result}
    rescue
      e ->
        {:error, "Failed to fetch bot metrics: #{Exception.message(e)}"}
    end
  end
end
