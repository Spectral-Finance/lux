defmodule Lux.Prisms.Telegram.Messaging.GetFile do
  @moduledoc """
  A prism for getting basic information about a file and prepare it for downloading.
  Particularly useful for voice messages.
  """
  use Lux.Prism

  alias Lux.Integrations.Telegram.Client

  def prism do
    %Lux.Prism{
      id: "telegram-get-file",
      name: "Get Telegram File Info",
      description: "Get basic info about a file and prepare it for downloading.",
      input_schema: %{
        type: :object,
        properties: %{
          file_id: %{
            type: :string,
            description: "File identifier to get info about."
          }
        },
        required: ["file_id"]
      },
      handler: &handler/2
    }
  end

  def handler(input, _ctx) do
    case Client.request(:post, "/getFile", %{json: input}) do
      {:ok, %{"result" => result}} ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
