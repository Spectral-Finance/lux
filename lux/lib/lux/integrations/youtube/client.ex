defmodule Lux.Integrations.YouTube.Client do
  @moduledoc """
  YouTube Data API v3 and YouTube Analytics API client helpers.

  The functions are thin request builders plus response normalizers so content
  intelligence workflows can be tested with `Req.Test`.
  """

  alias Lux.Integrations.YouTube

  @type opts :: keyword() | map()
  @type request_result :: {:ok, term()} | {:error, term()}

  @doc """
  Makes a YouTube API request.
  """
  @spec request(atom(), :data | :analytics, String.t(), opts()) :: request_result()
  def request(method, api, path, opts \\ %{}) do
    opts = normalize_opts(opts)

    [
      method: method,
      url: url(api, path, opts),
      headers: request_headers(opts),
      params: request_params(opts),
      retry: opt(opts, :retry, false)
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opt(opts, :plug))
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  @doc """
  Fetches YouTube video metadata and public statistics.
  """
  @spec videos([String.t()] | String.t(), opts()) :: request_result()
  def videos(video_ids, opts \\ %{}) do
    request(
      :get,
      :data,
      "/videos",
      put_params(opts, %{
        part: "snippet,statistics,contentDetails",
        id: join(video_ids)
      })
    )
  end

  @doc """
  Fetches channel metadata and public statistics.
  """
  @spec channels([String.t()] | String.t(), opts()) :: request_result()
  def channels(channel_ids, opts \\ %{}) do
    request(
      :get,
      :data,
      "/channels",
      put_params(opts, %{
        part: "snippet,statistics,contentDetails",
        id: join(channel_ids)
      })
    )
  end

  @doc """
  Searches videos for trend discovery.
  """
  @spec search(String.t(), opts()) :: request_result()
  def search(query, opts \\ %{}) do
    request(
      :get,
      :data,
      "/search",
      put_params(opts, %{
        part: "snippet",
        type: "video",
        q: query,
        maxResults: opt(normalize_opts(opts), :max_results, 10),
        order: opt(normalize_opts(opts), :order, "relevance")
      })
    )
  end

  @doc """
  Fetches region/category trending videos with `chart=mostPopular`.
  """
  @spec most_popular(opts()) :: request_result()
  def most_popular(opts \\ %{}) do
    opts = normalize_opts(opts)

    request(
      :get,
      :data,
      "/videos",
      put_params(opts, %{
        part: "snippet,statistics,contentDetails",
        chart: "mostPopular",
        regionCode: opt(opts, :region_code, "US"),
        videoCategoryId: opt(opts, :category_id),
        maxResults: opt(opts, :max_results, 10)
      })
    )
  end

  @doc """
  Queries YouTube Analytics reports for channel/video metrics.
  """
  @spec analytics_report(opts()) :: request_result()
  def analytics_report(opts) do
    opts = normalize_opts(opts)

    request(
      :get,
      :analytics,
      "/reports",
      put_params(opts, %{
        ids: opt(opts, :ids, "channel==MINE"),
        startDate: opt(opts, :start_date),
        endDate: opt(opts, :end_date),
        metrics:
          join(
            opt(opts, :metrics, ["views", "likes", "comments", "shares", "averageViewDuration"])
          ),
        dimensions: join(opt(opts, :dimensions)),
        filters: opt(opts, :filters),
        sort: opt(opts, :sort),
        maxResults: opt(opts, :max_results)
      })
    )
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}

  defp handle_response({:ok, %{status: status, body: body}}),
    do: {:error, YouTube.classify_error(status, body)}

  defp handle_response({:error, error}), do: {:error, error}

  defp url(:data, path, opts),
    do: opt(opts, :data_api_base_url, YouTube.data_api_base_url()) <> path

  defp url(:analytics, path, opts),
    do: opt(opts, :analytics_api_base_url, YouTube.analytics_api_base_url()) <> path

  defp request_headers(opts) do
    headers = opt(opts, :headers, YouTube.headers())

    case opt(opts, :access_token) do
      nil -> headers
      token -> [{"Authorization", "Bearer #{token}"} | headers]
    end
  end

  defp request_params(opts) do
    params = opt(opts, :params, %{}) |> drop_nil()

    case {opt(opts, :access_token), opt(opts, :api_key, YouTube.api_key())} do
      {nil, key} when is_binary(key) and key != "" -> Map.put_new(params, :key, key)
      _ -> params
    end
  end

  defp put_params(opts, params) do
    opts
    |> normalize_opts()
    |> Map.update(:params, params, &Map.merge(params, normalize_opts(&1)))
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp normalize_opts(opts) when is_map(opts), do: opts
  defp normalize_opts(opts) when is_list(opts), do: Map.new(opts)
  defp normalize_opts(nil), do: %{}

  defp opt(opts, key, default \\ nil) do
    cond do
      Map.has_key?(opts, key) -> Map.fetch!(opts, key)
      Map.has_key?(opts, to_string(key)) -> Map.fetch!(opts, to_string(key))
      true -> default
    end
  end

  defp join(nil), do: nil
  defp join(values) when is_list(values), do: Enum.join(values, ",")
  defp join(value), do: to_string(value)

  defp drop_nil(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)
end
