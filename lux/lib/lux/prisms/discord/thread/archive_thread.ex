defmodule Lux.Prisms.Discord.Thread.ArchiveThread do
  use Lux.Prism,
    name: "Archive Discord Thread",
    description: "Archives or unarchives a Discord thread",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Thread ID", pattern: "^[0-9]{17,20}$"},
        archived: %{type: :boolean, description: "Whether to archive the thread (default: true)"}
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{archived: %{type: :boolean}},
      required: ["archived"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, _agent) do
    archived = if is_boolean(params[:archived]), do: params[:archived], else: true
    case Client.request(:patch, "/channels/#{params[:channel_id]}", %{json: %{archived: archived}}) do
      {:ok, _} -> {:ok, %{archived: archived}}
      {:error, error} -> {:error, error}
    end
  end
end
