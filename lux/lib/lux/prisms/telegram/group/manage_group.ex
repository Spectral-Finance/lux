defmodule Lux.Prisms.Telegram.Group.ManageGroup do
  @moduledoc """
  Prism for Telegram group and channel management plans.
  """

  use Lux.Prism,
    name: "Manage Telegram Group",
    description:
      "Builds Telegram group moderation, permission, settings, channel post, and audit plans",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "permission_system",
            "member_action",
            "moderate_content",
            "moderation_action",
            "spam_protection",
            "group_settings",
            "channel_post",
            "audit_log"
          ]
        },
        params: %{type: :object}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        result: %{type: :object}
      },
      required: ["status", "result"]
    }

  alias Lux.Integrations.Telegram.GroupManager

  def handler(%{action: "permission_system"} = input, _ctx) do
    input |> params() |> GroupManager.permission_system() |> normalize_result()
  end

  def handler(%{action: "member_action"} = input, _ctx) do
    input |> params() |> GroupManager.member_action_plan() |> normalize_result()
  end

  def handler(%{action: "moderate_content"} = input, _ctx) do
    input
    |> params()
    |> then(&GroupManager.moderate_content(Map.get(&1, :message, %{}), Map.get(&1, :rules, %{})))
    |> normalize_result()
  end

  def handler(%{action: "moderation_action"} = input, _ctx) do
    input |> params() |> GroupManager.moderation_action_plan() |> normalize_result()
  end

  def handler(%{action: "spam_protection"} = input, _ctx) do
    input
    |> params()
    |> then(&GroupManager.spam_protection(Map.get(&1, :events, []), Map.get(&1, :rules, %{})))
    |> normalize_result()
  end

  def handler(%{action: "group_settings"} = input, _ctx) do
    input |> params() |> GroupManager.group_settings_plan() |> normalize_result()
  end

  def handler(%{action: "channel_post"} = input, _ctx) do
    input |> params() |> GroupManager.channel_post_plan() |> normalize_result()
  end

  def handler(%{action: "audit_log"} = input, _ctx) do
    input
    |> params()
    |> then(&GroupManager.audit_log(Map.get(&1, :entries, []), Map.get(&1, :filters, %{})))
    |> normalize_result()
  end

  def handler(_input, _ctx), do: {:error, "Unsupported Telegram group operation"}

  defp params(input), do: Map.get(input, :params, %{})

  defp normalize_result({:ok, result}), do: {:ok, %{status: "success", result: result}}
  defp normalize_result({:error, reason}), do: {:error, reason}
end
