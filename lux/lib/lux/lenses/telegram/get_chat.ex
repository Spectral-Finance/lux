defmodule Lux.Lenses.Telegram.GetChat do
  @moduledoc """
  Lens for getting chat information.
  """

  alias Lux.Integrations.Telegram.Client

  def focus(params, _opts \\ []) do
    chat_id = params[:chat_id] || params["chat_id"]
    Client.request("getChat", %{chat_id: chat_id}, build_opts(params))
  end

  defp build_opts(params) do
    opts = [token: params[:token] || params["token"]]
    if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts
  end
end
