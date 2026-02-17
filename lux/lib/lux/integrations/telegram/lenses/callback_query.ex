defmodule Lux.Integrations.Telegram.Lenses.CallbackQuery do
  @moduledoc """
  Lens for processing Telegram CallbackQuery updates.
  """

  require Logger

  alias Lux.Integrations.Telegram.Client

  @type callback_query :: %{
    optional(:id) => String.t(),
    optional(:from) => %{optional(:id) => integer()},
    optional(:message) => %{},
    optional(:data) => String.t()
  }

  @doc """
  Processes a Telegram CallbackQuery update.

  ## Parameters

    * `callback_query` - The CallbackQuery data to process

  ## Examples

      # Process a callback query
      iex> Lux.Integrations.Telegram.Lenses.CallbackQuery.process(%{
      ...>   id: "1234567890",
      ...>   from: %{id: 12345},
      ...>   message: %{},
      ...>   data: "button_clicked"
      ...> })
      :ok
  """
  @spec process(callback_query()) :: :ok | {:error, term()}
  def process(%{data: data}) do
    case data do
      "button_clicked" ->
        # Handle button click logic here
        Logger.info("Button clicked")
        :ok

      _ ->
        {:error, :unknown_data}
    end
  end
end