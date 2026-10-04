defmodule Lux.Prisms.Telegram.CallbackQueryPrism do
  @moduledoc """
  Prism for decoding and processing inline keyboard callback queries and pagination payloads.
  """

  use Lux.Prism,
    name: "Telegram Callback Query Prism",
    description: "Decodes compact callback data payloads, parses pagination requests, and formats answer responses.",
    input_schema: %{
      type: :object,
      properties: %{
        callback_data: %{type: :string, description: "Raw callback_data string from inline button"}
      },
      required: ["callback_data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        target: %{type: :string},
        item_id: %{type: :string},
        params: %{type: :object},
        page: %{type: :integer},
        total_pages: %{type: :integer}
      }
    }

  @impl true
  def handler(params, _agent) do
    callback_data = params[:callback_data] || params["callback_data"] || ""

    result =
      python variables: %{callback_data: callback_data} do
        ~PY"""
        from lux.telegram.callbacks import CallbackProcessor
        decoded = CallbackProcessor.decode(callback_data)
        {
            "action": str(decoded.action),
            "target": str(decoded.target) if decoded.target else None,
            "item_id": str(decoded.item_id) if decoded.item_id else None,
            "params": dict(decoded.params),
            "page": int(decoded.page) if decoded.page is not None else None,
            "total_pages": int(decoded.total_pages) if decoded.total_pages is not None else None
        }
        """
      end

    {:ok, result}
  rescue
    e in RuntimeError ->
      {:error, "Callback query decoding failed: #{Exception.message(e)}"}
  end
end
