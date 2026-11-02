defmodule Lux.Prisms.Discord.Thread.CreateThread do
  @moduledoc """
  A prism for creating a thread in a Discord channel.
  """

  use Lux.Prism,
    name: "Create Discord Thread",
    description: "Creates a thread in a Discord channel or starts a thread from a message",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel snowflake ID"},
        name: %{type: :string, description: "Thread name"},
        message_id: %{type: :string, description: "Optional message ID to start thread from"},
        auto_archive_duration: %{type: :integer, description: "Auto-archive duration in minutes (default 1440)"},
        rate_limit_per_user: %{type: :integer, description: "Slowmode for thread (default 0)"}
      },
      required: ["channel_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{type: :boolean},
        thread_id: %{type: :string},
        name: %{type: :string},
        channel_id: %{type: :string}
      },
      required: ["created", "thread_id", "name", "channel_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, name} <- validate_param(params, :name) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"
      Logger.info("Agent #{agent_name} creating thread '#{name}' in channel #{channel_id}")

      auto_archive_duration = Map.get(params, :auto_archive_duration, 1440)
      rate_limit_per_user = Map.get(params, :rate_limit_per_user, 0)

      body =
        params
        |> Map.take([:name, :auto_archive_duration, :rate_limit_per_user, :type])
        |> Map.put(:auto_archive_duration, auto_archive_duration)
        |> Map.put(:rate_limit_per_user, rate_limit_per_user)
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()

      endpoint =
        if msg_id = params[:message_id] do
          "/channels/#{channel_id}/messages/#{msg_id}/threads"
        else
          "/channels/#{channel_id}/threads"
        end

      opts = %{json: body}
      opts = if plug = params[:plug], do: Map.put(opts, :plug, plug), else: opts
      opts = if token = params[:token], do: Map.put(opts, :token, token), else: opts

      case Client.request(:post, endpoint, opts) do
        {:ok, %{"id" => thread_id} = response} ->
          {:ok, %{
            created: true,
            thread_id: thread_id,
            name: response["name"] || name,
            channel_id: channel_id
          }}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
