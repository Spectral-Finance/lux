defmodule Lux.Lenses.Telegram.GetUpdates do
  @moduledoc """
  Lens for polling updates via getUpdates API method.
  """

  alias Lux.Integrations.Telegram.Client

  def focus(params, _opts \\ []) do
    api_params = %{}
    api_params = if params[:offset], do: Map.put(api_params, :offset, params[:offset]), else: api_params
    api_params = if params[:limit], do: Map.put(api_params, :limit, params[:limit]), else: api_params
    api_params = if params[:timeout], do: Map.put(api_params, :timeout, params[:timeout]), else: api_params
    api_params = if params[:allowed_updates], do: Map.put(api_params, :allowed_updates, params[:allowed_updates]), else: api_params

    Client.request("getUpdates", api_params, build_opts(params))
  end

  defp build_opts(params) do
    opts = [token: params[:token] || params["token"]]
    if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts
  end
end
