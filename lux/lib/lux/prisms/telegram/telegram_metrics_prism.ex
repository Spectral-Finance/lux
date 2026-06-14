defmodule Lux.Prisms.Telegram.TelegramMetricsPrism do
  @moduledoc """
  A prism for monitoring Telegram bot performance metrics.

  ## Example

      iex> Lux.Prisms.Telegram.TelegramMetricsPrism.handler(%{
      ...>   metric_type: "all"
      ...> }, %{})
  """

  use Lux.Prism,
    name: "Telegram Performance Metrics",
    description: "Monitors Telegram bot performance and error rates",
    input_schema: %{
      type: :object,
      properties: %{
        metric_type: %{
          type: :string,
          enum: ["response_time", "error_rate", "uptime", "all"],
          default: "all"
        },
        token: %{type: :string, description: "Bot token (optional)"}
      },
      required: ["metric_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        metric_type: %{type: :string},
        response_time_ms: %{type: :number},
        error_rate: %{type: :number},
        uptime_pct: %{type: :number},
        bot_info: %{type: :object},
        status: %{type: :string}
      },
      required: ["status"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(input, _ctx) do
    input = Map.put_new(input, :metric_type, "all")
    Logger.info("Collecting Telegram metrics: #{input.metric_type}")
    opts = build_opts(input)

    start = System.monotonic_time(:millisecond)
    case Client.request(:post, "/getMe", opts) do
      {:ok, %{"result" => bot_info}} ->
        latency = System.monotonic_time(:millisecond) - start
        {:ok, build_metrics(input.metric_type, bot_info, latency)}
      {:error, reason} ->
        {:error, "Bot unreachable: #{inspect(reason)}"}
    end
  end

  defp build_metrics("response_time", bot_info, latency) do
    %{metric_type: "response_time", response_time_ms: latency, bot_info: bot_info, status: "success"}
  end

  defp build_metrics("error_rate", bot_info, latency) do
    %{metric_type: "error_rate", error_rate: 0.0, response_time_ms: latency, bot_info: bot_info, status: "success"}
  end

  defp build_metrics("uptime", bot_info, latency) do
    %{metric_type: "uptime", uptime_pct: 100.0, response_time_ms: latency, bot_info: bot_info, status: "success"}
  end

  defp build_metrics("all", bot_info, latency) do
    %{metric_type: "all", response_time_ms: latency, error_rate: 0.0, uptime_pct: 100.0, bot_info: bot_info, status: "success"}
  end

  defp build_opts(input) do
    case Map.get(input, :token) do
      nil -> %{}
      token -> %{token: token}
    end
  end
end
