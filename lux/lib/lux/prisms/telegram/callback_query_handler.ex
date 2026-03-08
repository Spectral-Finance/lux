defmodule Lux.Prisms.Telegram.CallbackQueryHandler do
  @moduledoc """
  Processes inline keyboard callback queries.

  Supports:
  - Answer callback queries (with text, alert, URL)
  - Parse callback data with structured routing
  - Edit originating message
  """

  use Lux.Prism,
    name: "Telegram Callback Query Handler",
    description: "Process and respond to inline keyboard callback queries",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["answer", "parse", "edit_message"]},
        token: %{type: :string},
        callback_query_id: %{type: :string},
        callback_data: %{type: :string},
        text: %{type: :string},
        show_alert: %{type: :boolean},
        url: %{type: :string},
        chat_id: %{type: :integer},
        message_id: %{type: :integer}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{result: %{type: :object}}
    }

  alias Lux.Integrations.Telegram.Client

  @impl true
  def handler(params, _agent) do
    action = params["action"] || params[:action]

    case action do
      "answer" -> answer_callback(params)
      "parse" -> parse_callback_data(params)
      "edit_message" -> edit_callback_message(params)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  @doc "Answer a callback query."
  def answer_callback(params) do
    token = params["token"] || params[:token]
    plug = params["plug"] || params[:plug]
    body = %{callback_query_id: params["callback_query_id"] || params[:callback_query_id]}
    |> maybe_put(:text, params["text"] || params[:text])
    |> maybe_put(:show_alert, params["show_alert"] || params[:show_alert])
    |> maybe_put(:url, params["url"] || params[:url])

    Client.request(:post, "/answerCallbackQuery", %{token: token, json: body, plug: plug})
  end

  @doc """
  Parse callback data into structured format.

  Supports formats:
  - `action:param1:param2` (colon-separated)
  - `action|key=val|key2=val2` (pipe-separated with named params)
  - Plain string
  """
  def parse_callback_data(params) do
    data = params["callback_data"] || params[:callback_data] || ""

    result = cond do
      String.contains?(data, "|") ->
        [action | pairs] = String.split(data, "|")
        named = Enum.reduce(pairs, %{}, fn pair, acc ->
          case String.split(pair, "=", parts: 2) do
            [k, v] -> Map.put(acc, k, v)
            _ -> acc
          end
        end)
        %{action: action, params: named, format: :pipe}

      String.contains?(data, ":") ->
        [action | args] = String.split(data, ":")
        %{action: action, args: args, format: :colon}

      true ->
        %{action: data, args: [], params: %{}, format: :plain}
    end

    {:ok, result}
  end

  @doc "Edit the message that triggered the callback."
  def edit_callback_message(params) do
    token = params["token"] || params[:token]
    plug = params["plug"] || params[:plug]
    body = %{
      chat_id: params["chat_id"] || params[:chat_id],
      message_id: params["message_id"] || params[:message_id],
      text: params["text"] || params[:text]
    }
    |> maybe_put(:parse_mode, params["parse_mode"] || params[:parse_mode])
    |> maybe_put(:reply_markup, params["reply_markup"] || params[:reply_markup])

    Client.request(:post, "/editMessageText", %{token: token, json: body, plug: plug})
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
