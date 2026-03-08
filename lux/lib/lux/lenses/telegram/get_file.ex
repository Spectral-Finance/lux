defmodule Lux.Lenses.Telegram.GetFile do
  @moduledoc """
  Lens for getting file info and download URL.
  """

  alias Lux.Integrations.Telegram.Client
  alias Lux.Integrations.Telegram

  def focus(params, _opts \\ []) do
    file_id = params[:file_id] || params["file_id"]
    token = params[:token] || params["token"]

    case Client.request("getFile", %{file_id: file_id}, build_opts(params)) do
      {:ok, file} ->
        download_url = Telegram.file_url(token, file["file_path"])
        {:ok, Map.put(file, "download_url", download_url)}

      error ->
        error
    end
  end

  defp build_opts(params) do
    opts = [token: params[:token] || params["token"]]
    if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts
  end
end
