defmodule Lux.Prisms.Telegram.Processing.ProcessCallbackQuery do
  @moduledoc """
  Processes callback queries from inline keyboards.
  """
  use Lux.Prism,
    name: "Process Callback Query",
    description: "Parses callback query data and extracts action and parameters",
    input_schema: %{
      type: :object,
      properties: %{
        callback_query: %{
          type: :object,
          description: "The callback query object from Telegram update"
        }
      },
      required: ["callback_query"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        from_id: %{type: :integer},
        message_id: %{type: :integer},
        data: %{type: :string},
        action: %{type: :string},
        params: %{
          type: :array,
          items: %{type: :string}
        }
      },
      required: ["id", "from_id"]
    }

  def handler(params, _ctx) do
    callback_query = Map.get(params, :callback_query) || Map.get(params, "callback_query")

    if is_map(callback_query) do
      id = Map.get(callback_query, "id")
      from_id = get_in(callback_query, ["from", "id"])
      message_id = get_in(callback_query, ["message", "message_id"])
      data = Map.get(callback_query, "data", "")

      # Parse data, assuming format "action:param1:param2" or similar
      [action | data_params] = 
        if data != "" do
          String.split(data, ":")
        else
          ["", []]
        end

      result = %{
        id: id,
        from_id: from_id,
        message_id: message_id,
        data: data,
        action: action,
        params: data_params
      }
      
      {:ok, result}
    else
      {:error, "Invalid callback query object"}
    end
  end
end
