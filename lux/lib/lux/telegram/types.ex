defmodule Lux.Telegram.Types do
  @moduledoc """
  Data structures and map-to-struct conversion functions for Telegram Bot API entities.
  """

  defmodule User do
    @moduledoc """
    Represents a Telegram user or bot.
    """
    defstruct [
      :id,
      :is_bot,
      :first_name,
      :last_name,
      :username,
      :language_code,
      :can_join_groups,
      :can_read_all_group_messages,
      :supports_inline_queries
    ]

    @type t :: %__MODULE__{
            id: integer() | nil,
            is_bot: boolean() | nil,
            first_name: String.t() | nil,
            last_name: String.t() | nil,
            username: String.t() | nil,
            language_code: String.t() | nil,
            can_join_groups: boolean() | nil,
            can_read_all_group_messages: boolean() | nil,
            supports_inline_queries: boolean() | nil
          }

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil
    def from_map(%__MODULE__{} = user), do: user

    def from_map(map) when is_map(map) do
      %__MODULE__{
        id: Lux.Telegram.Types.fetch_key(map, :id),
        is_bot: Lux.Telegram.Types.fetch_key(map, :is_bot),
        first_name: Lux.Telegram.Types.fetch_key(map, :first_name),
        last_name: Lux.Telegram.Types.fetch_key(map, :last_name),
        username: Lux.Telegram.Types.fetch_key(map, :username),
        language_code: Lux.Telegram.Types.fetch_key(map, :language_code),
        can_join_groups: Lux.Telegram.Types.fetch_key(map, :can_join_groups),
        can_read_all_group_messages: Lux.Telegram.Types.fetch_key(map, :can_read_all_group_messages),
        supports_inline_queries: Lux.Telegram.Types.fetch_key(map, :supports_inline_queries)
      }
    end

    def from_map(_), do: nil
  end

  defmodule Chat do
    @moduledoc """
    Represents a Telegram chat (private, group, supergroup, channel).
    """
    defstruct [
      :id,
      :type,
      :title,
      :username,
      :first_name,
      :last_name,
      :is_forum
    ]

    @type t :: %__MODULE__{
            id: integer() | String.t() | nil,
            type: String.t() | nil,
            title: String.t() | nil,
            username: String.t() | nil,
            first_name: String.t() | nil,
            last_name: String.t() | nil,
            is_forum: boolean() | nil
          }

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil
    def from_map(%__MODULE__{} = chat), do: chat

    def from_map(map) when is_map(map) do
      %__MODULE__{
        id: Lux.Telegram.Types.fetch_key(map, :id),
        type: Lux.Telegram.Types.fetch_key(map, :type),
        title: Lux.Telegram.Types.fetch_key(map, :title),
        username: Lux.Telegram.Types.fetch_key(map, :username),
        first_name: Lux.Telegram.Types.fetch_key(map, :first_name),
        last_name: Lux.Telegram.Types.fetch_key(map, :last_name),
        is_forum: Lux.Telegram.Types.fetch_key(map, :is_forum)
      }
    end

    def from_map(_), do: nil
  end

  defmodule Message do
    @moduledoc """
    Represents a Telegram message.
    """
    defstruct [
      :message_id,
      :message_thread_id,
      :from,
      :date,
      :chat,
      :text,
      :reply_to_message
    ]

    @type t :: %__MODULE__{
            message_id: integer() | nil,
            message_thread_id: integer() | nil,
            from: User.t() | nil,
            date: integer() | nil,
            chat: Chat.t() | nil,
            text: String.t() | nil,
            reply_to_message: t() | nil
          }

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil
    def from_map(%__MODULE__{} = msg), do: msg

    def from_map(map) when is_map(map) do
      %__MODULE__{
        message_id: Lux.Telegram.Types.fetch_key(map, :message_id),
        message_thread_id: Lux.Telegram.Types.fetch_key(map, :message_thread_id),
        from: User.from_map(Lux.Telegram.Types.fetch_key(map, :from)),
        date: Lux.Telegram.Types.fetch_key(map, :date),
        chat: Chat.from_map(Lux.Telegram.Types.fetch_key(map, :chat)),
        text: Lux.Telegram.Types.fetch_key(map, :text),
        reply_to_message: from_map(Lux.Telegram.Types.fetch_key(map, :reply_to_message))
      }
    end

    def from_map(_), do: nil
  end

  defmodule File do
    @moduledoc """
    Represents a Telegram file object.
    """
    defstruct [
      :file_id,
      :file_unique_id,
      :file_size,
      :file_path
    ]

    @type t :: %__MODULE__{
            file_id: String.t() | nil,
            file_unique_id: String.t() | nil,
            file_size: integer() | nil,
            file_path: String.t() | nil
          }

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil
    def from_map(%__MODULE__{} = file), do: file

    def from_map(map) when is_map(map) do
      %__MODULE__{
        file_id: Lux.Telegram.Types.fetch_key(map, :file_id),
        file_unique_id: Lux.Telegram.Types.fetch_key(map, :file_unique_id),
        file_size: Lux.Telegram.Types.fetch_key(map, :file_size),
        file_path: Lux.Telegram.Types.fetch_key(map, :file_path)
      }
    end

    def from_map(_), do: nil
  end

  defmodule WebhookInfo do
    @moduledoc """
    Represents current status of a Telegram webhook.
    """
    defstruct [
      :url,
      :has_custom_certificate,
      :pending_update_count,
      :ip_address,
      :last_error_date,
      :last_error_message,
      :last_synchronization_error_date,
      :max_connections,
      :allowed_updates
    ]

    @type t :: %__MODULE__{
            url: String.t() | nil,
            has_custom_certificate: boolean() | nil,
            pending_update_count: integer() | nil,
            ip_address: String.t() | nil,
            last_error_date: integer() | nil,
            last_error_message: String.t() | nil,
            last_synchronization_error_date: integer() | nil,
            max_connections: integer() | nil,
            allowed_updates: list(String.t()) | nil
          }

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil
    def from_map(%__MODULE__{} = info), do: info

    def from_map(map) when is_map(map) do
      %__MODULE__{
        url: Lux.Telegram.Types.fetch_key(map, :url),
        has_custom_certificate: Lux.Telegram.Types.fetch_key(map, :has_custom_certificate),
        pending_update_count: Lux.Telegram.Types.fetch_key(map, :pending_update_count),
        ip_address: Lux.Telegram.Types.fetch_key(map, :ip_address),
        last_error_date: Lux.Telegram.Types.fetch_key(map, :last_error_date),
        last_error_message: Lux.Telegram.Types.fetch_key(map, :last_error_message),
        last_synchronization_error_date: Lux.Telegram.Types.fetch_key(map, :last_synchronization_error_date),
        max_connections: Lux.Telegram.Types.fetch_key(map, :max_connections),
        allowed_updates: Lux.Telegram.Types.fetch_key(map, :allowed_updates)
      }
    end

    def from_map(_), do: nil
  end

  defmodule Response do
    @moduledoc """
    Represents a Telegram API response container.
    """
    defstruct [
      :ok,
      :result,
      :error_code,
      :description,
      :parameters
    ]

    @type t :: %__MODULE__{
            ok: boolean() | nil,
            result: term(),
            error_code: integer() | nil,
            description: String.t() | nil,
            parameters: map() | nil
          }

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil
    def from_map(%__MODULE__{} = resp), do: resp

    def from_map(map) when is_map(map) do
      %__MODULE__{
        ok: Lux.Telegram.Types.fetch_key(map, :ok),
        result: Lux.Telegram.Types.fetch_key(map, :result),
        error_code: Lux.Telegram.Types.fetch_key(map, :error_code),
        description: Lux.Telegram.Types.fetch_key(map, :description),
        parameters: Lux.Telegram.Types.fetch_key(map, :parameters)
      }
    end

    def from_map(_), do: nil
  end

  defmodule InlineKeyboardButton do
    @moduledoc """
    Represents one button of an inline keyboard.
    """
    defstruct [
      :text,
      :url,
      :callback_data,
      :web_app,
      :login_url,
      :switch_inline_query,
      :switch_inline_query_current_chat,
      :switch_inline_query_chosen_chat,
      :callback_game,
      :pay
    ]

    @type t :: %__MODULE__{
            text: String.t() | nil,
            url: String.t() | nil,
            callback_data: String.t() | nil,
            web_app: map() | nil,
            login_url: map() | nil,
            switch_inline_query: String.t() | nil,
            switch_inline_query_current_chat: String.t() | nil,
            switch_inline_query_chosen_chat: map() | nil,
            callback_game: map() | nil,
            pay: boolean() | nil
          }

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil
    def from_map(%__MODULE__{} = btn), do: btn

    def from_map(map) when is_map(map) do
      %__MODULE__{
        text: Lux.Telegram.Types.fetch_key(map, :text),
        url: Lux.Telegram.Types.fetch_key(map, :url),
        callback_data: Lux.Telegram.Types.fetch_key(map, :callback_data),
        web_app: Lux.Telegram.Types.fetch_key(map, :web_app),
        login_url: Lux.Telegram.Types.fetch_key(map, :login_url),
        switch_inline_query: Lux.Telegram.Types.fetch_key(map, :switch_inline_query),
        switch_inline_query_current_chat: Lux.Telegram.Types.fetch_key(map, :switch_inline_query_current_chat),
        switch_inline_query_chosen_chat: Lux.Telegram.Types.fetch_key(map, :switch_inline_query_chosen_chat),
        callback_game: Lux.Telegram.Types.fetch_key(map, :callback_game),
        pay: Lux.Telegram.Types.fetch_key(map, :pay)
      }
    end

    def from_map(_), do: nil
  end

  defmodule InlineKeyboardMarkup do
    @moduledoc """
    Represents an inline keyboard that appears right next to the message it belongs to.
    """
    defstruct [:inline_keyboard]

    @type t :: %__MODULE__{
            inline_keyboard: list(list(InlineKeyboardButton.t() | map())) | nil
          }

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil
    def from_map(%__MODULE__{} = kb), do: kb

    def from_map(map) when is_map(map) do
      rows = Lux.Telegram.Types.fetch_key(map, :inline_keyboard) || []

      normalized_rows =
        Enum.map(rows, fn row ->
          Enum.map(row, &InlineKeyboardButton.from_map/1)
        end)

      %__MODULE__{inline_keyboard: normalized_rows}
    end

    def from_map(_), do: nil
  end

  defmodule KeyboardButton do
    @moduledoc """
    Represents one button of the reply keyboard.
    """
    defstruct [
      :text,
      :request_users,
      :request_chat,
      :request_contact,
      :request_location,
      :request_poll,
      :web_app
    ]

    @type t :: %__MODULE__{
            text: String.t() | nil,
            request_users: map() | nil,
            request_chat: map() | nil,
            request_contact: boolean() | nil,
            request_location: boolean() | nil,
            request_poll: map() | nil,
            web_app: map() | nil
          }

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil
    def from_map(%__MODULE__{} = btn), do: btn

    def from_map(map) when is_map(map) do
      %__MODULE__{
        text: Lux.Telegram.Types.fetch_key(map, :text),
        request_users: Lux.Telegram.Types.fetch_key(map, :request_users),
        request_chat: Lux.Telegram.Types.fetch_key(map, :request_chat),
        request_contact: Lux.Telegram.Types.fetch_key(map, :request_contact),
        request_location: Lux.Telegram.Types.fetch_key(map, :request_location),
        request_poll: Lux.Telegram.Types.fetch_key(map, :request_poll),
        web_app: Lux.Telegram.Types.fetch_key(map, :web_app)
      }
    end

    def from_map(_), do: nil
  end

  defmodule ReplyKeyboardMarkup do
    @moduledoc """
    Represents a custom keyboard with reply options.
    """
    defstruct [
      :keyboard,
      :is_persistent,
      :resize_keyboard,
      :one_time_keyboard,
      :input_field_placeholder,
      :selective
    ]

    @type t :: %__MODULE__{
            keyboard: list(list(KeyboardButton.t() | map())) | nil,
            is_persistent: boolean() | nil,
            resize_keyboard: boolean() | nil,
            one_time_keyboard: boolean() | nil,
            input_field_placeholder: String.t() | nil,
            selective: boolean() | nil
          }

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil
    def from_map(%__MODULE__{} = kb), do: kb

    def from_map(map) when is_map(map) do
      rows = Lux.Telegram.Types.fetch_key(map, :keyboard) || []

      normalized_rows =
        Enum.map(rows, fn row ->
          Enum.map(row, &KeyboardButton.from_map/1)
        end)

      %__MODULE__{
        keyboard: normalized_rows,
        is_persistent: Lux.Telegram.Types.fetch_key(map, :is_persistent),
        resize_keyboard: Lux.Telegram.Types.fetch_key(map, :resize_keyboard),
        one_time_keyboard: Lux.Telegram.Types.fetch_key(map, :one_time_keyboard),
        input_field_placeholder: Lux.Telegram.Types.fetch_key(map, :input_field_placeholder),
        selective: Lux.Telegram.Types.fetch_key(map, :selective)
      }
    end

    def from_map(_), do: nil
  end

  defmodule ReplyKeyboardRemove do
    @moduledoc """
    Upon receiving a message with this object, Telegram clients will remove the current custom keyboard.
    """
    defstruct remove_keyboard: true, selective: nil

    @type t :: %__MODULE__{
            remove_keyboard: boolean(),
            selective: boolean() | nil
          }

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil
    def from_map(%__MODULE__{} = kb), do: kb

    def from_map(map) when is_map(map) do
      %__MODULE__{
        remove_keyboard: Lux.Telegram.Types.fetch_key(map, :remove_keyboard) || true,
        selective: Lux.Telegram.Types.fetch_key(map, :selective)
      }
    end

    def from_map(_), do: nil
  end

  defmodule ForceReply do
    @moduledoc """
    Upon receiving a message with this object, Telegram clients will display a reply interface to the user.
    """
    defstruct force_reply: true, input_field_placeholder: nil, selective: nil

    @type t :: %__MODULE__{
            force_reply: boolean(),
            input_field_placeholder: String.t() | nil,
            selective: boolean() | nil
          }

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil
    def from_map(%__MODULE__{} = kb), do: kb

    def from_map(map) when is_map(map) do
      %__MODULE__{
        force_reply: Lux.Telegram.Types.fetch_key(map, :force_reply) || true,
        input_field_placeholder: Lux.Telegram.Types.fetch_key(map, :input_field_placeholder),
        selective: Lux.Telegram.Types.fetch_key(map, :selective)
      }
    end

    def from_map(_), do: nil
  end

  defmodule Update do
    @moduledoc """
    Represents an incoming Telegram update.
    """
    defstruct [
      :update_id,
      :message,
      :edited_message,
      :channel_post,
      :edited_channel_post,
      :inline_query,
      :chosen_inline_result,
      :callback_query,
      :shipping_query,
      :pre_checkout_query,
      :poll,
      :poll_answer,
      :my_chat_member,
      :chat_member,
      :chat_join_request
    ]

    @type t :: %__MODULE__{
            update_id: integer() | nil,
            message: Message.t() | nil,
            edited_message: Message.t() | nil,
            channel_post: Message.t() | nil,
            edited_channel_post: Message.t() | nil,
            inline_query: map() | nil,
            chosen_inline_result: map() | nil,
            callback_query: map() | nil,
            shipping_query: map() | nil,
            pre_checkout_query: map() | nil,
            poll: map() | nil,
            poll_answer: map() | nil,
            my_chat_member: map() | nil,
            chat_member: map() | nil,
            chat_join_request: map() | nil
          }

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil
    def from_map(%__MODULE__{} = update), do: update

    def from_map(map) when is_map(map) do
      %__MODULE__{
        update_id: Lux.Telegram.Types.fetch_key(map, :update_id),
        message: Message.from_map(Lux.Telegram.Types.fetch_key(map, :message)),
        edited_message: Message.from_map(Lux.Telegram.Types.fetch_key(map, :edited_message)),
        channel_post: Message.from_map(Lux.Telegram.Types.fetch_key(map, :channel_post)),
        edited_channel_post: Message.from_map(Lux.Telegram.Types.fetch_key(map, :edited_channel_post)),
        inline_query: Lux.Telegram.Types.fetch_key(map, :inline_query),
        chosen_inline_result: Lux.Telegram.Types.fetch_key(map, :chosen_inline_result),
        callback_query: Lux.Telegram.Types.fetch_key(map, :callback_query),
        shipping_query: Lux.Telegram.Types.fetch_key(map, :shipping_query),
        pre_checkout_query: Lux.Telegram.Types.fetch_key(map, :pre_checkout_query),
        poll: Lux.Telegram.Types.fetch_key(map, :poll),
        poll_answer: Lux.Telegram.Types.fetch_key(map, :poll_answer),
        my_chat_member: Lux.Telegram.Types.fetch_key(map, :my_chat_member),
        chat_member: Lux.Telegram.Types.fetch_key(map, :chat_member),
        chat_join_request: Lux.Telegram.Types.fetch_key(map, :chat_join_request)
      }
    end

    def from_map(_), do: nil

    @spec to_map(t() | nil) :: map() | nil
    def to_map(nil), do: nil
    def to_map(%__MODULE__{} = update), do: Lux.Telegram.Types.to_map(update)
  end

  @doc """
  Helper function to fetch key from map supporting atom and string keys.
  """
  def fetch_key(map, key) when is_map(map) and is_atom(key) do
    case Map.fetch(map, key) do
      {:ok, val} -> val
      :error -> Map.get(map, Atom.to_string(key))
    end
  end

  def fetch_key(_map, _key), do: nil

  @doc """
  Casts a map representation to the specified struct module.
  """
  def from_map(type_module, map) do
    if function_exported?(type_module, :from_map, 1) do
      type_module.from_map(map)
    else
      map
    end
  end

  @doc """
  Converts a struct or map to a Telegram API compatible map with nil values removed.
  Recursively processes nested structs, maps, and lists.
  """
  def to_map(nil), do: nil

  def to_map(%struct_mod{} = struct)
      when struct_mod in [
             User,
             Chat,
             Message,
             File,
             WebhookInfo,
             Response,
             InlineKeyboardMarkup,
             InlineKeyboardButton,
             ReplyKeyboardMarkup,
             KeyboardButton,
             ReplyKeyboardRemove,
             ForceReply,
             Update
           ] do
    struct
    |> Map.from_struct()
    |> to_map()
  end

  def to_map(map) when is_map(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {k, to_map(v)} end)
  end

  def to_map(list) when is_list(list) do
    Enum.map(list, &to_map/1)
  end

  def to_map(other), do: other
end

defimpl Jason.Encoder,
  for: [
    Lux.Telegram.Types.User,
    Lux.Telegram.Types.Chat,
    Lux.Telegram.Types.Message,
    Lux.Telegram.Types.File,
    Lux.Telegram.Types.WebhookInfo,
    Lux.Telegram.Types.Response,
    Lux.Telegram.Types.InlineKeyboardMarkup,
    Lux.Telegram.Types.InlineKeyboardButton,
    Lux.Telegram.Types.ReplyKeyboardMarkup,
    Lux.Telegram.Types.KeyboardButton,
    Lux.Telegram.Types.ReplyKeyboardRemove,
    Lux.Telegram.Types.ForceReply,
    Lux.Telegram.Types.Update
  ] do
  def encode(struct, opts) do
    map = Lux.Telegram.Types.to_map(struct)
    Jason.Encode.map(map, opts)
  end
end

