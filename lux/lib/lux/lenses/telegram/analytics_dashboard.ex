defmodule Lux.Lenses.Telegram.AnalyticsDashboard do
  @moduledoc """
  A lens for viewing the Telegram analytics dashboard.

  Provides a read-only view into the analytics data collected by the
  Telegram analytics engine. This lens queries the local analytics
  engine directly rather than making HTTP requests.

  ## Examples

      iex> AnalyticsDashboard.focus(%{section: "messages"})
      {:ok, %{total_sent: 100, total_received: 50, ...}}

      iex> AnalyticsDashboard.focus(%{section: "all"})
      {:ok, %{messages: %{...}, commands: %{...}, ...}}
  """

  alias Lux.Integrations.Telegram.Analytics

  @schema %{
    type: :object,
    properties: %{
      section: %{
        type: :string,
        description: "Analytics section to view",
        enum: ["all", "messages", "commands", "engagement", "errors", "performance", "usage_patterns"]
      }
    },
    required: ["section"]
  }

  @doc """
  Returns a lens-like view struct with metadata about this lens.
  """
  @spec view() :: map()
  def view do
    %{
      name: "Telegram Analytics Dashboard",
      description: "Reads Telegram bot analytics data for dashboard display",
      method: :get,
      schema: @schema
    }
  end

  @doc """
  Focuses the analytics lens on a specific section.

  ## Parameters

    * `input` — Map with `:section` key (default: `"all"`)
    * `opts` — Options (unused, for API compatibility)

  ## Sections

    * `"all"` — Full dashboard with all metrics
    * `"messages"` — Message statistics
    * `"commands"` — Command usage statistics
    * `"engagement"` — User engagement metrics
    * `"errors"` — Error statistics
    * `"performance"` — Performance metrics
    * `"usage_patterns"` — Usage pattern analysis

  ## Examples

      iex> AnalyticsDashboard.focus(%{section: "messages"})
      {:ok, %{total_sent: 10, total_received: 5, ...}}
  """
  @spec focus(map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def focus(input \\ %{}, _opts \\ []) do
    section = Map.get(input, :section, "all")
    fetch_section(section)
  end

  defp fetch_section("all"), do: {:ok, Analytics.get_dashboard()}
  defp fetch_section("messages"), do: {:ok, Analytics.get_message_stats()}
  defp fetch_section("commands"), do: {:ok, Analytics.get_command_stats()}
  defp fetch_section("engagement"), do: {:ok, Analytics.get_user_engagement()}
  defp fetch_section("errors"), do: {:ok, Analytics.get_error_stats()}
  defp fetch_section("performance"), do: {:ok, Analytics.get_performance_metrics()}
  defp fetch_section("usage_patterns"), do: {:ok, Analytics.get_usage_patterns()}
  defp fetch_section(section), do: {:error, "Unknown section: #{section}"}
end
