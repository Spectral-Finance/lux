defmodule Lux.Integrations.Telegram.Prism do
  @moduledoc """
  Module for handling Telegram Prisms.
  """

  require Logger

  @endpoint "https://api.telegram.org/bot"

  @type prism_opts :: %{
    optional(:token) => String.t(),
    optional(:json) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:plug) => {module(), term()}
  }

  @doc """
  Processes a Telegram Prism.

  ## Parameters

    * `prism` - The prism to process
    * `opts` - Processing options (see Options section)

  ## Options

    * `:token` - Telegram Bot API token (required)
    * `:json` - Additional data for processing
    * `:headers` - Additional headers to include
    * `:plug` - A plug to use for testing instead of making real HTTP requests

  ## Examples

      # Process a prism
      iex> Telegram.Prism.process(%{
      ...>   token: "your_bot_token",
      ...>   json: %{data: "some_data"}
      ...> })
      {:ok, %{"processed" => true}}
  """
  @spec process(map(), prism_opts()) :: {:ok, map()} | {:error, term()}
  def process(prism, opts \\ %{}) do
    import Lux.Config
    import Lux.Lenses
    url = @endpoint <> token <> "/processPrism"

    [
      method: :post,
      url: url,
      headers: [
        {"Content-Type", "application/json"}
      ],
      json: Map.put(prism, :data, opts[:json])
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
          |> maybe_add_plug(opts[:plug])
          |> Req.new()
          |> Req.request()
          |> handle_response()
  end

  defp maybe_add_pl

def handle_outbound_message(message, opts \\ %{}) do
  import Lux.Config
  import Lux.Lenses
  url = @endpoint <> token <> "/sendPrism"

  [
    method: :post,
    url: url,
    headers: [
      {"Content-Type", "application/json"}
    ],
    json: message
  ]
  |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
        |> maybe_add_plug(opts[:plug])
        |> Req.new()
        |> Req.request()
        |> handle_response()
end

defp maybe_add_plug(request, nil), do: request
defp maybe_add_plug(request, plug), do: Plug.Conn.send_request(plug, request)