defmodule Lux.Integrations.Telegram.MessageProcessing.CommandRouter do
  @moduledoc """
  Command routing engine with permission guards, chat-type filters,
  help generation, and BotFather commands list formatting.
  """

  @type route_handler :: (map(), map() -> {:ok, term()} | {:error, term()}) | module()

  @type command_spec :: %{
          description: String.t(),
          handler: route_handler(),
          permissions: list(atom()),
          chat_types: list(atom()),
          usage: String.t(),
          hidden: boolean()
        }

  @doc """
  Creates a new empty router struct.
  """
  def new do
    %{
      routes: %{},
      fallback: &__MODULE__.default_fallback/2,
      middleware: []
    }
  end

  @doc """
  Registers a command route with the router.

  ## Options:
    - `:description` - Short summary of what the command does
    - `:usage` - Example usage string (e.g. "/swap <from> <to> <amount>")
    - `:permissions` - List of required permissions (e.g. [:admin, :owner])
    - `:chat_types` - Allowed chat types (e.g. [:private, :group, :supergroup])
    - `:hidden` - Whether to hide from /help listing (default false)
  """
  def register(router, command_name, handler, opts \\ []) do
    cmd = String.downcase(to_string(command_name))

    spec = %{
      command: cmd,
      handler: handler,
      description: Keyword.get(opts, :description, "No description"),
      usage: Keyword.get(opts, :usage, "/#{cmd}"),
      permissions: Keyword.get(opts, :permissions, []),
      chat_types: Keyword.get(opts, :chat_types, [:private, :group, :supergroup]),
      hidden: Keyword.get(opts, :hidden, false)
    }

    put_in(router, [:routes, cmd], spec)
  end

  @doc """
  Sets a fallback handler for unregistered or unhandled commands.
  """
  def set_fallback(router, fallback_fn) when is_function(fallback_fn, 2) do
    %{router | fallback: fallback_fn}
  end

  @doc """
  Routes a parsed command given the context.
  Context can include:
    - `:user_id` - ID of the sender
    - `:chat_type` - `:private`, `:group`, `:supergroup`, or `:channel`
    - `:is_admin` - boolean flag
    - `:is_owner` - boolean flag
  """
  def dispatch(router, parsed_cmd, context \\ %{})

  def dispatch(router, %{is_command: true, command: cmd_name} = parsed, context) do
    case Map.get(router.routes, cmd_name) do
      nil ->
        router.fallback.(parsed, context)

      spec ->
        with :ok <- check_chat_type(spec, context),
             :ok <- check_permissions(spec, context) do
          execute_handler(spec.handler, parsed, context)
        end
    end
  end

  def dispatch(_router, %{is_command: false}, _context) do
    {:error, :not_a_command}
  end

  def dispatch(_router, _, _context) do
    {:error, :invalid_command_payload}
  end

  @doc """
  Formats all registered visible commands into BotFather menu syntax:
  `command1 - Description one`
  `command2 - Description two`
  """
  def format_botfather_commands(router) do
    router.routes
    |> Map.values()
    |> Enum.reject(& &1.hidden)
    |> Enum.sort_by(& &1.command)
    |> Enum.map(fn spec -> "#{spec.command} - #{spec.description}" end)
    |> Enum.join("\n")
  end

  @doc """
  Generates a formatted help text for all registered commands.
  """
  def generate_help_text(router, format \\ :markdown) do
    commands =
      router.routes
      |> Map.values()
      |> Enum.reject(& &1.hidden)
      |> Enum.sort_by(& &1.command)

    case format do
      :markdown ->
        lines =
          Enum.map(commands, fn spec ->
            "*#{spec.usage}* - #{spec.description}"
          end)

        "🤖 *Available Commands:*\n\n" <> Enum.join(lines, "\n")

      :html ->
        lines =
          Enum.map(commands, fn spec ->
            "<b>#{spec.usage}</b> - #{spec.description}"
          end)

        "🤖 <b>Available Commands:</b>\n\n" <> Enum.join(lines, "\n")
    end
  end

  # Default fallback handler
  def default_fallback(parsed, _context) do
    {:error, {:unknown_command, parsed.command}}
  end

  # --- Internal Guards & Execution ---

  defp check_chat_type(%{chat_types: allowed}, %{chat_type: chat_type}) do
    type_atom = if is_binary(chat_type), do: String.to_atom(chat_type), else: chat_type

    if type_atom in allowed do
      :ok
    else
      {:error, {:chat_type_not_allowed, type_atom}}
    end
  end

  defp check_chat_type(_, _), do: :ok

  defp check_permissions(%{permissions: req_perms}, context) do
    cond do
      :admin in req_perms and not Map.get(context, :is_admin, false) and not Map.get(context, :is_owner, false) ->
        {:error, :permission_denied}

      :owner in req_perms and not Map.get(context, :is_owner, false) ->
        {:error, :permission_denied}

      true ->
        :ok
    end
  end

  defp execute_handler(handler, parsed, context) when is_function(handler, 2) do
    handler.(parsed, context)
  end

  defp execute_handler(handler_module, parsed, context) when is_atom(handler_module) do
    if Code.ensure_loaded?(handler_module) and function_exported?(handler_module, :handler, 2) do
      handler_module.handler(%{command: parsed, context: context}, %{})
    else
      {:ok, %{status: :dispatched, module: handler_module, parsed: parsed}}
    end
  end
end
