defmodule Lux.Prisms.YouTube.Videos.InitiateResumableUpload do
  @moduledoc """
  Starts a YouTube resumable upload session for a video metadata payload.
  """

  use Lux.Prism,
    name: "Initiate YouTube Resumable Upload",
    description: "Creates a YouTube resumable upload session for video metadata",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string, description: "Video title"},
        description: %{type: :string, description: "Video description"},
        privacy_status: %{
          type: :string,
          enum: ["private", "public", "unlisted"],
          description: "Video privacy status"
        },
        token: %{type: :string, description: "Optional OAuth2 access token"}
      },
      required: ["title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        upload_url: %{type: :string, description: "Resumable upload session URL"},
        title: %{type: :string, description: "Video title"},
        privacy_status: %{type: :string, description: "Video privacy status"}
      },
      required: ["upload_url", "title"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, title} <- validate_string(params, :title) do
      privacy_status = Map.get(params, :privacy_status, "private")

      metadata = %{
        snippet: %{
          title: title,
          description: Map.get(params, :description, "")
        },
        status: %{privacyStatus: privacy_status}
      }

      case Client.initiate_resumable_upload(metadata, request_opts(params)) do
        {:ok, %{"location" => upload_url}} ->
          {:ok, %{upload_url: upload_url, title: title, privacy_status: privacy_status}}

        {:error, error} ->
          {:error, "Failed to initiate YouTube upload: #{inspect(error)}"}
      end
    end
  end

  defp validate_string(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp request_opts(%{token: token}) when is_binary(token) and token != "", do: %{token: token}
  defp request_opts(_params), do: %{}
end
