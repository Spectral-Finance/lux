defmodule Lux.Integrations.YouTube.LiveClient do
  @moduledoc """
  YouTube Data API v3 Core Integration and Live Streaming manager (#68).
  """

  @api_base "https://www.googleapis.com/youtube/v3"

  def base_url, do: @api_base

  def build_live_broadcast_payload(title, scheduled_start_iso, privacy_status \\ "public")
      when is_binary(title) and is_binary(scheduled_start_iso) do
    trimmed = String.trim(title)

    cond do
      trimmed == "" ->
        {:error, :empty_title}

      privacy_status not in ["public", "unlisted", "private"] ->
        {:error, :invalid_privacy_status}

      true ->
        {:ok,
         %{
           snippet: %{
             title: String.slice(trimmed, 0, 100),
             scheduledStartTime: scheduled_start_iso
           },
           status: %{
             privacyStatus: privacy_status,
             selfDeclaredMadeForKids: false
           },
           contentDetails: %{
             enableAutoStart: true,
             enableAutoStop: true
           }
         }}
    end
  end
end
