defmodule Lux.Prisms.Twitter.UploadMedia do
  @moduledoc """
  A prism for uploading media (images, videos, GIFs) to Twitter.

  ## Examples

      # Upload an image from a file
      iex> {:ok, data} = File.read("/path/to/image.png")
      iex> UploadMedia.handler(%{media_data: data, media_type: "image/png"}, %{name: "Agent"})
      {:ok, %{media_id: "123456789"}}

      # Upload from base64-encoded data
      iex> UploadMedia.handler(%{media_data: base64_string, encoding: :base64, media_type: "image/jpeg"}, %{name: "Agent"})
      {:ok, %{media_id: "123456789"}}
  """

  use Lux.Prism,
    name: "Upload Media",
    description: "Uploads media (image, video, GIF) to Twitter for use in tweets",
    input_schema: %{
      type: :object,
      properties: %{
        media_data: %{
          type: :string,
          description: "Raw binary data or base64-encoded media content"
        },
        media_type: %{
          type: :string,
          description: "MIME type of the media (e.g. image/png, image/jpeg, image/gif, video/mp4)",
          enum: ["image/png", "image/jpeg", "image/gif", "video/mp4"]
        },
        encoding: %{
          type: :string,
          description: "Encoding of media_data. Use 'base64' if data is base64-encoded",
          enum: ["raw", "base64"],
          default: "raw"
        },
        chunked: %{
          type: :boolean,
          description: "Whether to use chunked upload (required for large media > 5MB)",
          default: false
        }
      },
      required: ["media_data", "media_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        media_id: %{type: :string, description: "The media ID returned by Twitter"},
        media_type: %{type: :string, description: "The MIME type of the uploaded media"},
        size: %{type: :integer, description: "Size in bytes"}
      },
      required: ["media_id"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Handles uploading media to Twitter.

  Returns {:ok, %{media_id, media_type, size}} on success.
  """
  def handler(params, agent) do
    with {:ok, media_data} <- validate_param(params, :media_data),
         {:ok, media_type} <- validate_param(params, :media_type),
         {:ok, encoding} <- validate_optional_string(params, :encoding, "raw"),
         {:ok, chunked} <- validate_optional_bool(params, :chunked, false) do

      agent_name = agent[:name] || "Unknown Agent"
      processed_data = decode_media(media_data, encoding)
      Logger.info("Agent #{agent_name} uploading #{media_type} (#{byte_size(processed_data)} bytes)")

      case Client.upload_media(processed_data, media_type) do
        {:ok, %{"media_id_string" => media_id, "media_key" => _media_key} = resp} ->
          size = Map.get(resp, "size_bytes", byte_size(processed_data))
          Logger.info("Successfully uploaded media #{media_id}")
          {:ok, %{media_id: media_id, media_type: media_type, size: size}}

        {:ok, %{"media_id_string" => media_id}} ->
          Logger.info("Successfully uploaded media #{media_id}")
          {:ok, %{media_id: media_id, media_type: media_type, size: byte_size(processed_data)}}

        {:error, {status, body}} ->
          Logger.error("Failed to upload media: #{inspect(body)}")
          {:error, {status, body}}
      end
    end
  end

  defp decode_media(data, "base64"), do: Base.decode64!(data)
  defp decode_media(data, "raw"), do: data

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_optional_string(params, key, default \\ "") do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      :error -> {:ok, default}
      _ -> {:error, "Invalid #{key}"}
    end
  end

  defp validate_optional_bool(params, key, default \\ false) do
    case Map.fetch(params, key) do
      {:ok, value} when is_boolean(value) -> {:ok, value}
      :error -> {:ok, default}
      _ -> {:error, "Invalid #{key}"}
    end
  end
end
