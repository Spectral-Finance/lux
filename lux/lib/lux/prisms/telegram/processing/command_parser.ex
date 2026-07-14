defmodule Lux.Prisms.Telegram.Processing.CommandParser do
  @moduledoc """
  A prism for parsing Telegram commands and extracting parameters.
  
  Identifies if a message text is a command (starts with '/'), handles targeted commands
  (like '/start@botname'), and extracts any arguments passed with the command.
  """

  use Lux.Prism,
    name: "Telegram Command Parser",
    description: "Parses Telegram commands and extracts parameters",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "Message text to parse"
        },
        bot_username: %{
          type: :string,
          description: "Optional bot username to check for targeted commands"
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        is_command: %{
          type: :boolean,
          description: "Whether the text is a command"
        },
        command: %{
          type: :string,
          description: "The extracted command (without /)"
        },
        args: %{
          type: :array,
          items: %{type: :string},
          description: "List of arguments passed to the command"
        }
      },
      required: ["is_command"]
    }

  def handler(%{text: text} = params, _agent) when is_binary(text) do
    bot_username = Map.get(params, :bot_username)
    
    cond do
      not String.starts_with?(text, "/") ->
        {:ok, %{is_command: false}}

      true ->
        parse_command(text, bot_username)
    end
  end

  def handler(_params, _agent) do
    {:ok, %{is_command: false}}
  end

  defp parse_command(text, bot_username) do
    parts = 
      text
      |> String.split(" ", trim: true)
    
    case parts do
      [] -> 
        {:ok, %{is_command: false}}
        
      [command_part | args] ->
        # Remove the leading '/'
        command = String.slice(command_part, 1..-1//1)
        
        {final_command, is_valid_target} =
          if String.contains?(command, "@") do
            [cmd, target] = String.split(command, "@", parts: 2)
            {cmd, bot_username == nil or String.downcase(target) == String.downcase(bot_username)}
          else
            {command, true}
          end
          
        if is_valid_target do
          {:ok, %{
            is_command: true,
            command: final_command,
            args: args
          }}
        else
          {:ok, %{is_command: false}}
        end
    end
  end
end
