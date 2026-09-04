defmodule Lux.Telegram.Keyboards do
  @moduledoc """
  Helper module for generating Telegram bot keyboards and markup.
  """

  alias Lux.Telegram.Types.ForceReply
  alias Lux.Telegram.Types.InlineKeyboardButton
  alias Lux.Telegram.Types.InlineKeyboardMarkup
  alias Lux.Telegram.Types.KeyboardButton
  alias Lux.Telegram.Types.ReplyKeyboardMarkup
  alias Lux.Telegram.Types.ReplyKeyboardRemove

  defmodule InlineKeyboardMarkup do
    @moduledoc false
    defstruct [:inline_keyboard]
  end

  defmodule InlineKeyboardButton do
    @moduledoc false
    defstruct [:text, :url, :callback_data, :web_app, :login_url, :switch_inline_query, :switch_inline_query_current_chat, :switch_inline_query_chosen_chat, :callback_game, :pay]
  end

  defmodule ReplyKeyboardMarkup do
    @moduledoc false
    defstruct [:keyboard, :is_persistent, :resize_keyboard, :one_time_keyboard, :input_field_placeholder, :selective]
  end

  defmodule KeyboardButton do
    @moduledoc false
    defstruct [:text, :request_users, :request_chat, :request_contact, :request_location, :request_poll, :web_app]
  end

  defmodule ReplyKeyboardRemove do
    @moduledoc false
    defstruct remove_keyboard: true, selective: nil
  end

  defmodule ForceReply do
    @moduledoc false
    defstruct force_reply: true, input_field_placeholder: nil, selective: nil
  end

  @doc """
  Constructs an inline keyboard markup struct from rows of inline buttons.

  ## Examples

      iex> Keyboards.inline_keyboard([[Keyboards.inline_button("Click", "data_1")]])
      %Lux.Telegram.Types.InlineKeyboardMarkup{inline_keyboard: [[%Lux.Telegram.Types.InlineKeyboardButton{text: "Click", callback_data: "data_1"}]]}
  """
  def inline_keyboard(rows) when is_list(rows) do
    normalized_rows =
      Enum.map(rows, fn row ->
        Enum.map(row, fn
          %Lux.Telegram.Types.InlineKeyboardButton{} = btn ->
            btn

          {text, cb} when is_binary(cb) ->
            inline_button(text, cb)

          {text, opts} when is_list(opts) or is_map(opts) ->
            inline_button(text, opts)

          btn when is_map(btn) ->
            Lux.Telegram.Types.InlineKeyboardButton.from_map(btn)

          btn ->
            btn
        end)
      end)

    %Lux.Telegram.Types.InlineKeyboardMarkup{inline_keyboard: normalized_rows}
  end

  @doc """
  Constructs an inline keyboard button struct.

  ## Examples

      iex> Keyboards.inline_button("Click me", "callback_data_1")
      %Lux.Telegram.Types.InlineKeyboardButton{text: "Click me", callback_data: "callback_data_1"}

      iex> Keyboards.inline_button("Visit Site", url: "https://example.com")
      %Lux.Telegram.Types.InlineKeyboardButton{text: "Visit Site", url: "https://example.com"}
  """
  def inline_button(text, callback_data) when is_binary(callback_data) do
    %Lux.Telegram.Types.InlineKeyboardButton{text: text, callback_data: callback_data}
  end

  def inline_button(text, opts) when is_list(opts) or is_map(opts) do
    opts_map = if is_list(opts), do: Map.new(opts), else: opts
    Lux.Telegram.Types.InlineKeyboardButton.from_map(Map.put(opts_map, :text, text))
  end

  @doc """
  Constructs a KeyboardButton struct.
  """
  def keyboard_button(text, opts \\ %{}) when is_binary(text) do
    opts_map = if is_list(opts), do: Map.new(opts), else: opts || %{}
    Lux.Telegram.Types.KeyboardButton.from_map(Map.put(opts_map, :text, text))
  end

  @doc """
  Constructs a ReplyKeyboardMarkup struct from rows of button texts or button structs/maps.

  ## Examples

      iex> Keyboards.reply_keyboard([["Yes", "No"]], resize_keyboard: true)
      %Lux.Telegram.Types.ReplyKeyboardMarkup{keyboard: [[%Lux.Telegram.Types.KeyboardButton{text: "Yes"}, %Lux.Telegram.Types.KeyboardButton{text: "No"}]], resize_keyboard: true}
  """
  def reply_keyboard(rows, opts \\ %{}) when is_list(rows) do
    opts_map = if is_list(opts), do: Map.new(opts), else: opts || %{}

    normalized_rows =
      Enum.map(rows, fn row ->
        Enum.map(row, fn
          %Lux.Telegram.Types.KeyboardButton{} = btn ->
            btn

          btn when is_binary(btn) ->
            %Lux.Telegram.Types.KeyboardButton{text: btn}

          btn when is_map(btn) ->
            Lux.Telegram.Types.KeyboardButton.from_map(btn)

          btn ->
            %Lux.Telegram.Types.KeyboardButton{text: to_string(btn)}
        end)
      end)

    opts_map
    |> Map.put(:keyboard, normalized_rows)
    |> then(&Lux.Telegram.Types.ReplyKeyboardMarkup.from_map/1)
  end

  @doc """
  Constructs a ReplyKeyboardRemove struct.

  ## Examples

      iex> Keyboards.remove_reply_keyboard(selective: true)
      %Lux.Telegram.Types.ReplyKeyboardRemove{remove_keyboard: true, selective: true}
  """
  def remove_reply_keyboard(opts \\ %{}) do
    opts_map = if is_list(opts), do: Map.new(opts), else: opts || %{}
    opts_map
    |> Map.put_new(:remove_keyboard, true)
    |> then(&Lux.Telegram.Types.ReplyKeyboardRemove.from_map/1)
  end

  @doc """
  Alias for remove_reply_keyboard/1.
  """
  def reply_keyboard_remove(opts \\ %{}), do: remove_reply_keyboard(opts)

  @doc """
  Constructs a ForceReply struct.

  ## Examples

      iex> Keyboards.force_reply(selective: true)
      %Lux.Telegram.Types.ForceReply{force_reply: true, selective: true}
  """
  def force_reply(opts \\ %{}) do
    opts_map = if is_list(opts), do: Map.new(opts), else: opts || %{}
    opts_map
    |> Map.put_new(:force_reply, true)
    |> then(&Lux.Telegram.Types.ForceReply.from_map/1)
  end

  @doc """
  Converts any keyboard struct, map, or nested list into a cleaned Telegram API-compliant map.
  """
  def to_map(markup) do
    Lux.Telegram.Types.to_map(markup)
  end
end
