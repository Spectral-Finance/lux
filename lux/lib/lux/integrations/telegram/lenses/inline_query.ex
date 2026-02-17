defmodule Lux.Integrations.Telegram.Lenses.InlineQuery do
  @moduledoc """
  Lens for processing Telegram InlineQuery updates.
  """

  require Logger

  alias Lux.Integrations.Telegram.Client

  @type inline_query :: %{
    optional(:id) => String.t(),
    optional(:from) => map(),
    optional(:query) => String.t(),
    optional(:offset) => String.t()
  }

  @doc """
  Processes an InlineQuery update.

  ## Parameters

    * `inline_query` - The InlineQuery update to process
    * `opts` - Request options (see Options section)

  ## Options

    * `:token` - Telegram Bot API token (required)
    * `:json` - Additional data to include in the response
    * `:headers` - Additional headers to include
    * `:plug` - A plug to use for testing instead of making real HTTP requests

  ## Examples

      # Process an InlineQuery update
      iex> Telegram.Lenses.InlineQuery.process(%{
      ...>   id: "123456789",
      ...>   from: %{"id" => 123_456_789, "is_bot" => false},
      ...>   query: "hello",
      ...>   offset: ""
      ...> }, %{token: "your_bot_token"})
      {:ok, %{"inline_query_id" => "123456789", "results" => []}}
  """
  @spec process(inline_query(), request_opts()) :: {:ok, map()} | {:error, term()}
  def process(%{id: id} = inline_query, opts \\ %{}) do
    token = opts[:token] || Lux.Config.telegram_bot_token()
    url = Client.@endpoint <> token <> "/answerInlineQuery"

    [
      method: :post,
      url: url,
      headers: [
        {"Content-Type", "application/json"}
      ],
      json: Map.put(inline_query, :results, [])
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
          |> maybe_add_plug(opts[:plug])
          |> Req.new()
          |> Req.request()
          |> handle_response()
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp handle_response({:ok, %{"ok" => true} = response}), do: {:ok, response}
  defp handle_response({:ok, %{"ok" => false} = response}), do: {:error, response["description"]}
  defp handle_response(error), do: error
end