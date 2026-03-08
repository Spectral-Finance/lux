defmodule Lux.Lenses.Telegram.GetMe do
  @moduledoc """
  Lens for getting bot information via getMe API method.
  """

  alias Lux.Integrations.Telegram.Client

  def focus(params, _opts \\ []) do
    Client.request("getMe", %{}, build_opts(params))
  end

  defp build_opts(params) do
    opts = [token: params[:token] || params["token"]]
    if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts
  end
end
