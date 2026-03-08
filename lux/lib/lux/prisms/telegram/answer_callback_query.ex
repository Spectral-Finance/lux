defmodule Lux.Prisms.Telegram.AnswerCallbackQuery do
  @moduledoc """
  Prism for answering inline keyboard callback queries.
  """

  use Lux.Prism,
    name: "Telegram Answer Callback",
    description: "Answer callback queries from inline keyboards",
    input_schema: %{
      type: :object,
      properties: %{
        callback_query_id: %{type: :string},
        text: %{type: :string},
        show_alert: %{type: :boolean},
        url: %{type: :string},
        token: %{type: :string}
      },
      required: ["callback_query_id", "token"]
    },
    output_schema: %{type: :object}

  alias Lux.Integrations.Telegram.Client

  @impl true
  def handler(params, _opts) do
    api_params =
      %{callback_query_id: params[:callback_query_id] || params["callback_query_id"]}
      |> maybe_put(:text, params[:text] || params["text"])
      |> maybe_put(:show_alert, params[:show_alert] || params["show_alert"])
      |> maybe_put(:url, params[:url] || params["url"])

    Client.request("answerCallbackQuery", api_params, build_opts(params))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp build_opts(params) do
    opts = [token: params[:token] || params["token"]]
    if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts
  end
end
