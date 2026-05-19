defmodule Lux.Prisms.Telegram.Management.GetFile do
  @moduledoc """
  A prism for getting basic info about a file and preparing it for downloading.
  """

  alias Lux.Integrations.Telegram.Client

  use Lux.Prism,
    name: "Get Telegram File",
    description: "Returns a File object with file_path for downloading",
    input_schema: %{
      type: :object,
      properties: %{
        file_id: %{type: :string, description: "File identifier to get info about"}
      },
      required: ["file_id"]
    }

  def handler(params, _agent) do
    case Client.request(:get, "/getFile", %{json: params}) do
      {:ok, %{"ok" => true, "result" => result}} ->
        {:ok, result}

      {:ok, response} ->
        {:error, response}

      {:error, error} ->
        {:error, error}
    end
  end
end
