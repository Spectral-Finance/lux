defmodule Lux.Prisms.Telegram.DeleteMessage do
  @moduledoc """
  Prism for deleting messages in Telegram.
  """

  use Lux.Prism,
    name: "Telegram Delete Message",
    description: "Delete a message from a chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer]},
        message_id: %{type: :integer},
        token: %{type: :string}
      },
      required: ["chat_id", "message_id", "token"]
    },
    output_schema: %{type: :object}

  alias Lux.Integrations.Telegram.Client

  @impl true
  def handler(params, _opts) do
    api_params = %{
      chat_id: params[:chat_id] || params["chat_id"],
      message_id: params[:message_id] || params["message_id"]
    }

    Client.request("deleteMessage", api_params, build_opts(params))
  end

  defp build_opts(params) do
    opts = [token: params[:token] || params["token"]]
    if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts
  end
end
