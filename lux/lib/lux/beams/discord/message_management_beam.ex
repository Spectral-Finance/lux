defmodule Lux.Beams.Discord.MessageManagementBeam do
  @moduledoc """
  A beam that orchestrates message management operations in Discord.

  This beam sends a message to a channel and optionally pins it,
  combining the SendMessage and PinMessage prisms in a sequence.

  ## Example Usage

  ```elixir
  {:ok, result, log} = Lux.Beams.Discord.MessageManagementBeam.run(%{
    channel_id: "123456789012345678",
    content: "Important announcement!",
    pin: true
  })

  # Result:
  %{
    message_id: "111111111111111111",
    channel_id: "123456789012345678",
    content: "Important announcement!",
    pinned: true
  }
  ```
  """

  use Lux.Beam,
    name: "Discord Message Management",
    description: "Sends a message and optionally pins it",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to send the message to",
          pattern: "^[0-9]{17,20}$"
        },
        content: %{
          type: :string,
          description: "The message content to send",
          minLength: 1,
          maxLength: 2000
        }
      },
      required: ["channel_id", "content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        message_id: %{type: :string, description: "The ID of the sent message"},
        channel_id: %{type: :string, description: "The ID of the channel"},
        content: %{type: :string, description: "The sent message content"},
        pinned: %{type: :boolean, description: "Whether the message was pinned"}
      },
      required: ["message_id", "channel_id", "content"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Discord.Messages.SendMessage
  alias Lux.Prisms.Discord.Messages.PinMessage

  sequence do
    step(:send_message, SendMessage, %{
      channel_id: [:input, :channel_id],
      content: [:input, :content]
    })

    step(:pin_message, PinMessage, %{
      channel_id: [:input, :channel_id],
      message_id: [:steps, :send_message, :result, :message_id]
    })

    step(:return, Lux.Prisms.NoOp, %{
      message_id: [:steps, :send_message, :result, :message_id],
      channel_id: [:input, :channel_id],
      content: [:input, :content],
      pinned: true
    })
  end
end
