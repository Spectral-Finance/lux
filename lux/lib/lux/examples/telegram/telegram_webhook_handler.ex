defmodule TelegramWebhookHandler do
  @moduledoc """
  A Plug for handling Telegram webhook requests.
  """
  use Plug.Router

  alias Lux.Lenses.Telegram.Client
  require Logger

  # Add more verbose logging
  plug Plug.Logger, log: :debug
  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  # Log all incoming requests
  @impl true
  def call(conn, opts) do
    # Log the request
    IO.puts("\n🔍 INCOMING REQUEST at #{DateTime.utc_now()}")
    IO.puts("🔍 Path: #{conn.request_path}")
    IO.puts("🔍 Method: #{conn.method}")
    IO.puts("🔍 Headers: #{inspect(conn.req_headers)}")
    IO.puts("🔍 Path info: #{inspect(conn.path_info)}")
    IO.puts("🔍 Query string: #{inspect(conn.query_string)}")
    IO.puts("🔍 Remote IP: #{inspect(conn.remote_ip)}")

    # Add the token to the connection assigns
    conn = assign(conn, :token, opts.token)

    # Override the path if specified
    if opts.path != "/webhook" do
      path_parts = String.split(opts.path, "/", trim: true)
      IO.puts("🔄 Routing request to custom path: #{opts.path} (parts: #{inspect(path_parts)})")
      %{conn | path_info: path_parts}
      |> super(opts)
    else
      super(conn, opts)
    end
  end

  # Match the webhook path - make it match any path to debug
  post _ do
    # Get the token from the options
    token = conn.assigns[:token]

    # Log the request
    IO.puts("\n🔔 WEBHOOK REQUEST RECEIVED at #{DateTime.utc_now()}")
    IO.puts("🔍 Path: #{conn.request_path}")
    IO.puts("🔍 Headers: #{inspect(conn.req_headers)}")
    IO.puts("🔍 Full Body: #{inspect(conn.body_params)}")

    # Process the update
    update = conn.body_params

    # Process the update in a separate process to avoid blocking
    spawn(fn ->
      processed_update = process_webhook_update(update)
      IO.puts("🔄 Processing update: #{inspect(processed_update)}")
      handle_update(processed_update, token)
    end)

    # Respond with 200 OK immediately
    send_resp(conn, 200, "")
  end

  # Handle all other requests
  match _ do
    IO.puts("\n❓ Received request to unmatched path: #{inspect(conn.path_info)}")
    send_resp(conn, 404, "Not found")
  end

  # Process an update received from Telegram
  defp process_webhook_update(update) do
    # Parse the update based on its type
    cond do
      Map.has_key?(update, "message") ->
        {:message, update["message"]}

      Map.has_key?(update, "edited_message") ->
        {:edited_message, update["edited_message"]}

      Map.has_key?(update, "channel_post") ->
        {:channel_post, update["channel_post"]}

      Map.has_key?(update, "edited_channel_post") ->
        {:edited_channel_post, update["edited_channel_post"]}

      Map.has_key?(update, "callback_query") ->
        {:callback_query, update["callback_query"]}

      Map.has_key?(update, "poll") ->
        {:poll, update["poll"]}

      Map.has_key?(update, "poll_answer") ->
        {:poll_answer, update["poll_answer"]}

      true ->
        {:unknown, update}
    end
  end

  # Handle a processed update
  defp handle_update({:message, message}, token) do
    # Get message details
    chat_id = message["chat"]["id"]
    message_id = message["message_id"]
    from_user = get_user_name(message["from"])

    # Check if the message has text
    if Map.has_key?(message, "text") do
      text = message["text"]
      IO.puts("\n📩 INCOMING MESSAGE: Chat ID: #{chat_id}, From: #{from_user}, Text: #{text}")
      IO.puts("⏱️ Time: #{DateTime.utc_now()}")

      # Echo the message back
      echo_text = "Echo: #{text}"
      send_message(chat_id, echo_text, message_id, token)
    else
      IO.puts("\n📩 Received non-text message from #{from_user} in chat #{chat_id}")
    end
  end

  defp handle_update({:edited_message, message}, token) do
    # Get message details
    chat_id = message["chat"]["id"]
    message_id = message["message_id"]
    from_user = get_user_name(message["from"])

    # Check if the message has text
    if Map.has_key?(message, "text") do
      text = message["text"]
      IO.puts("\n✏️ EDITED MESSAGE: Chat ID: #{chat_id}, From: #{from_user}, Text: #{text}")
      IO.puts("⏱️ Time: #{DateTime.utc_now()}")

      # Echo the edited message back
      echo_text = "Echo (edited): #{text}"
      send_message(chat_id, echo_text, message_id, token)
    else
      IO.puts("\n✏️ Received edited non-text message from #{from_user} in chat #{chat_id}")
    end
  end

  defp handle_update(update_type, _token) do
    IO.puts("\n📩 Received update of type: #{inspect(update_type)}")
  end

  # Get a user's name (first name + last name if available)
  defp get_user_name(user) do
    first_name = user["first_name"] || ""
    last_name = user["last_name"] || ""

    if last_name != "" do
      "#{first_name} #{last_name}"
    else
      first_name
    end
  end

  # Send a message in reply to another message
  defp send_message(chat_id, text, reply_to_message_id, token) do
    # Create the request parameters
    request_params = %{
      chat_id: chat_id,
      text: text,
      reply_to_message_id: reply_to_message_id
    }

    # Make the request
    url = "https://api.telegram.org/bot#{token}/sendMessage"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: request_params
    }

    case Client.make_request(lens, lens.params) do
      {:ok, response} ->
        IO.puts("✅ Sent echo reply with message ID: #{response["message_id"]}")

      {:error, error} ->
        IO.puts("❌ Error sending echo reply: #{inspect(error)}")
    end
  end

  @impl true
  def init(opts) do
    # Extract options
    token = Keyword.get(opts, :token)
    path = Keyword.get(opts, :path, "/webhook")

    # Log initialization
    IO.puts("\n🚀 INITIALIZING WEBHOOK HANDLER at #{DateTime.utc_now()}")
    IO.puts("🚀 Webhook path: #{path}")
    IO.puts("🚀 Token present: #{token != nil}")

    # Store the token and path
    %{token: token, path: path}
  end
end
