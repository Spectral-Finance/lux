defmodule Lux.Lenses.Telegram.GetGroupMemberCount do
  @moduledoc """
  Lens for retrieving the member count of a Telegram group/channel.
  """

  alias Lux.Integrations.Telegram.Client

  def focus(params, _opts \\ []) do
    token = params[:token] || params["token"] || ""
    chat_id = params[:chat_id] || params["chat_id"]
    plug = params[:plug] || params["plug"]

    case Client.request(:post, "/getChatMemberCount", %{token: token, json: %{chat_id: chat_id}, plug: plug}) do
      {:ok, %{"result" => count}} -> {:ok, %{member_count: count}}
      {:ok, count} when is_integer(count) -> {:ok, %{member_count: count}}
      error -> error
    end
  end
end
