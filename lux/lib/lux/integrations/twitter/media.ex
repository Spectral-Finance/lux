defmodule Lux.Integrations.Twitter.Media do
  @moduledoc """
  Handles media uploads to Twitter v1.1 upload API (`https://upload.twitter.com/1.1/media/upload.json`).
  Supports simple image uploads (< 5MB) and chunked uploads (INIT -> APPEND -> FINALIZE -> STATUS)
  for videos (MP4) and large animated GIFs up to 512MB.
  """

  alias Lux.Integrations.Twitter.Client

  @upload_endpoint "https://upload.twitter.com/1.1"

  @doc """
  Uploads a simple media file (PNG, JPG, WEBP) using base64 encoded payload.
  """
  @spec upload_simple(binary(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def upload_simple(binary_data, media_type \\ "image/jpeg", opts \\ %{}) do
    encoded = Base.encode64(binary_data)

    form_params = %{
      "media_data" => encoded,
      "media_category" => category_for_type(media_type)
    }

    req_opts =
      opts
      |> Map.put(:endpoint, @upload_endpoint)
      |> Map.put(:params, form_params)

    case Client.request(:post, "/media/upload.json", req_opts) do
      {:ok, %{"media_id_string" => id_str} = res} ->
        {:ok,
         %{
           media_id: id_str,
           size: byte_size(binary_data),
           media_type: media_type,
           raw: res
         }}

      {:ok, other} ->
        {:ok, other}

      error ->
        error
    end
  end

  @doc """
  Executes an INIT step for chunked media upload.
  """
  @spec chunked_init(non_neg_integer(), String.t(), String.t() | nil, map()) ::
          {:ok, String.t()} | {:error, term()}
  def chunked_init(total_bytes, media_type, media_category \\ nil, opts \\ %{}) do
    category = media_category || category_for_type(media_type)

    params = %{
      "command" => "INIT",
      "total_bytes" => to_string(total_bytes),
      "media_type" => media_type,
      "media_category" => category
    }

    req_opts =
      opts
      |> Map.put(:endpoint, @upload_endpoint)
      |> Map.put(:params, params)

    case Client.request(:post, "/media/upload.json", req_opts) do
      {:ok, %{"media_id_string" => id_str}} ->
        {:ok, id_str}

      {:ok, %{"media_id" => id}} ->
        {:ok, to_string(id)}

      error ->
        error
    end
  end

  @doc """
  Executes an APPEND step for a chunk of media data.
  """
  @spec chunked_append(String.t(), non_neg_integer(), binary(), map()) ::
          :ok | {:error, term()}
  def chunked_append(media_id, segment_index, chunk_binary, opts \\ %{}) do
    params = %{
      "command" => "APPEND",
      "media_id" => media_id,
      "segment_index" => to_string(segment_index),
      "media_data" => Base.encode64(chunk_binary)
    }

    req_opts =
      opts
      |> Map.put(:endpoint, @upload_endpoint)
      |> Map.put(:params, params)

    case Client.request(:post, "/media/upload.json", req_opts) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Executes a FINALIZE step for a chunked media upload.
  """
  @spec chunked_finalize(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def chunked_finalize(media_id, opts \\ %{}) do
    params = %{
      "command" => "FINALIZE",
      "media_id" => media_id
    }

    req_opts =
      opts
      |> Map.put(:endpoint, @upload_endpoint)
      |> Map.put(:params, params)

    Client.request(:post, "/media/upload.json", req_opts)
  end

  @doc """
  Checks processing status of an uploaded chunked video/GIF.
  """
  @spec check_status(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def check_status(media_id, opts \\ %{}) do
    params = %{
      "command" => "STATUS",
      "media_id" => media_id
    }

    req_opts =
      opts
      |> Map.put(:endpoint, @upload_endpoint)
      |> Map.put(:params, params)

    Client.request(:get, "/media/upload.json", req_opts)
  end

  defp category_for_type("video/mp4"), do: "tweet_video"
  defp category_for_type("image/gif"), do: "tweet_gif"
  defp category_for_type(_), do: "tweet_image"
end
