defmodule Lux.Prisms.Telegram.Interactive.AnswerCallbackQuery do
  @moduledoc """
  A prism for answering callback queries from inline keyboards.
  """

  use Lux.Prism,
    name: "Answer Telegram Callback Query",
    description: "Answers a callback query from an inline keyboard",
    input_schema: %{
      type: :object,
      properties: %{
        callback_query_id: %{type: :string, description: "The ID of the callback query to answer"},
        text: %{type: :string, description: "Text of the notification (0-200 characters)", maxLength: 200},
        show_alert: %{type: :boolean, description: "If true, an alert will be shown instead of a notification"},
        url: %{type: :string, description: "URL to be opened"},
        cache_time: %{type: :integer, description: "Maximum amount of time in seconds that the result may be cached"}
      },
      required: ["callback_query_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        answered: %{type: :boolean, description: "Whether the callback query was answered"}
      },
      required: ["answered"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, callback_query_id} <- validate_param(params, :callback_query_id) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} answering callback query #{callback_query_id}")

      json = %{callback_query_id: callback_query_id}
      json = maybe_add_optional(json, params, :text)
      json = maybe_add_optional(json, params, :show_alert)
      json = maybe_add_optional(json, params, :url)
      json = maybe_add_optional(json, params, :cache_time)

      case Client.request(:post, "/answerCallbackQuery", %{json: json}) do
        {:ok, _result} ->
          Logger.info("Successfully answered callback query #{callback_query_id}")
          {:ok, %{answered: true}}

        {:error, {status, description}} ->
          Logger.error("Failed to answer callback query: {#{status}, #{description}}")
          {:error, {status, description}}

        {:error, error} ->
          Logger.error("Failed to answer callback query: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_boolean(value) -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp maybe_add_optional(json, params, key) do
    case Map.fetch(params, key) do
      {:ok, value} -> Map.put(json, key, value)
      :error -> json
    end
  end
end
