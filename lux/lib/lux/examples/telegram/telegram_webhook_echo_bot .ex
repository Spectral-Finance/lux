defmodule Lux.Examples.Telegram.WebhookEchoBot do
  @moduledoc """
  A Telegram webhook echo bot that uses ngrok to expose a local server.
  """

  use GenServer
  alias Lux.Lenses.Telegram.Client
  require Logger

  @doc """
  Starts a webhook echo bot that uses ngrok to expose a local server.

  ## Parameters

  - `token`: Your Telegram Bot API token
  - `opts`: Additional options
    - `:port`: The local port to run the server on (default: 4000)
    - `:path`: The webhook path (default: "/webhook")
    - `:max_runtime`: Maximum runtime in seconds (default: 300 - 5 minutes)

  ## Example

  ```elixir
  # Start the webhook echo bot with your token
  Lux.Examples.Telegram.WebhookEchoBot.start("YOUR_BOT_TOKEN")

  # Start with custom options
  Lux.Examples.Telegram.WebhookEchoBot.start("YOUR_BOT_TOKEN", max_runtime: 60, port: 8080)
  ```
  """
  def start(token, opts \\ []) do
    # Start the GenServer
    {:ok, pid} = GenServer.start_link(__MODULE__, {token, opts}, name: __MODULE__)

    # Store the PID and token in the application environment for cleanup on exit
    :application.set_env(:lux, :telegram_webhook_pid, pid)
    :application.set_env(:lux, :telegram_webhook_token, token)

    # Register a cleanup handler for when the application exits
    :application.set_env(:elixir, :at_exit, fn _ ->
      # Get the PID and token from the application environment
      case :application.get_env(:lux, :telegram_webhook_pid) do
        {:ok, webhook_pid} when is_pid(webhook_pid) ->
          # Stop the GenServer gracefully
          GenServer.stop(webhook_pid, :normal, 5000)
        _ ->
          :ok
      end

      # As a fallback, ensure the webhook is deleted even if the GenServer cleanup fails
      case :application.get_env(:lux, :telegram_webhook_token) do
        {:ok, stored_token} when is_binary(stored_token) ->
          IO.puts("\n🔄 Emergency webhook deletion during shutdown...")
          url = "https://api.telegram.org/bot#{stored_token}/deleteWebhook"

          lens = %{
            url: url,
            method: :post,
            headers: [{"content-type", "application/json"}],
            params: %{drop_pending_updates: true}
          }

          case Client.make_request(lens, lens.params) do
            {:ok, true} ->
              IO.puts("✅ Webhook deleted during emergency shutdown")
            {:error, error} ->
              IO.puts("❌ Failed to delete webhook during emergency shutdown: #{inspect(error)}")
          end
        _ ->
          :ok
      end
    end)

    # Set up a simpler approach for handling Ctrl+C
    # This uses the standard Erlang process flag to trap exits
    Process.flag(:trap_exit, true)

    # Add a specific handler for SIGINT (Ctrl+C)
    # This ensures the webhook is deleted when the user presses Ctrl+C
    case :os.type() do
      {:unix, _} ->
        # Register a SIGINT handler
        spawn(fn ->
          # Use port to run a shell command that waits for SIGINT
          port = Port.open({:spawn, "trap 'exit 0' INT; while true; do sleep 1; done"}, [:binary])

          # When the shell command exits (due to SIGINT), perform emergency cleanup
          receive do
            {^port, {:exit_status, _}} ->
              IO.puts("\n🛑 Received SIGINT (Ctrl+C). Performing emergency webhook deletion...")

              # Get the token from the application environment
              case :application.get_env(:lux, :telegram_webhook_token) do
                {:ok, stored_token} when is_binary(stored_token) ->
                  # Delete the webhook directly
                  url = "https://api.telegram.org/bot#{stored_token}/deleteWebhook"

                  lens = %{
                    url: url,
                    method: :post,
                    headers: [{"content-type", "application/json"}],
                    params: %{drop_pending_updates: true}
                  }

                  case Client.make_request(lens, lens.params) do
                    {:ok, true} ->
                      IO.puts("✅ Webhook deleted during SIGINT handling")
                    {:error, error} ->
                      IO.puts("❌ Failed to delete webhook during SIGINT handling: #{inspect(error)}")
                  end

                  # Exit the VM
                  System.stop(0)
                _ ->
                  :ok
              end
          end
        end)
      _ ->
        :ok
    end

    # Create a process that will handle cleanup on shutdown
    spawn_link(fn ->
      # This process will receive an EXIT signal when the parent process exits
      Process.flag(:trap_exit, true)

      # Monitor the main process
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} ->
          # Main process has terminated, ensure cleanup
          IO.puts("\n🛑 Main process terminated. Ensuring cleanup...")
          # Give the GenServer's terminate callback time to run
          :timer.sleep(1000)
          # Exit the VM
          System.stop(0)
      end
    end)

    # Wait for the process to finish
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} ->
        :ok
    end
  end

  @impl true
  def init({token, opts}) do
    # Extract options
    port = Keyword.get(opts, :port, 4000)
    path = Keyword.get(opts, :path, "/webhook")
    max_runtime = Keyword.get(opts, :max_runtime, 300)

    IO.puts("Starting Telegram Webhook Echo Bot...")
    IO.puts("Press Ctrl+C to stop the bot")
    IO.puts("Bot will automatically stop after #{max_runtime} seconds")

    # Trap exits to ensure cleanup on termination
    Process.flag(:trap_exit, true)

    # Start the webhook server
    {:ok, webhook_pid} = start_webhook_server(token, port, path)

    IO.puts("Webhook server started on port #{port}")

    # Start ngrok to create a tunnel
    {ngrok_port, ngrok_url} = start_ngrok(port)
    webhook_url = ngrok_url <> path

    IO.puts("ngrok tunnel established at #{ngrok_url}")
    IO.puts("Setting webhook to #{webhook_url}")

    # Set the webhook
    case set_webhook(token, webhook_url) do
      {:ok, true} ->
        IO.puts("✅ Webhook set successfully!")

        # Get webhook info to verify
        case get_webhook_info(token) do
          {:ok, info} ->
            IO.puts("Webhook URL: #{info["url"]}")
            IO.puts("Pending update count: #{info["pending_update_count"]}")
            IO.puts("Has custom certificate: #{info["has_custom_certificate"]}")
            IO.puts("Last error date: #{info["last_error_date"]}")
            IO.puts("Last error message: #{info["last_error_message"]}")
            IO.puts("Max connections: #{info["max_connections"]}")
            IO.puts("Allowed updates: #{inspect(info["allowed_updates"])}")

            # Send a test message to ourselves
            IO.puts("\n📤 Sending a test message to the bot...")
            case get_me(token) do
              {:ok, bot_info} ->
                bot_username = bot_info["username"]
                IO.puts("Bot username: @#{bot_username}")
                IO.puts("Please send a message to @#{bot_username} to test the webhook.")
              _ ->
                IO.puts("❌ Could not get bot information.")
            end

            # If there are pending updates, process them manually
            pending_count = info["pending_update_count"] || 0
            if pending_count > 0 do
              IO.puts("\n🔄 Processing #{pending_count} pending updates manually...")
              process_pending_updates(token)
            end

            # Schedule shutdown after max_runtime
            if max_runtime > 0 do
              Process.send_after(self(), :shutdown, max_runtime * 1000)
            end

            # Return the initial state
            {:ok, %{
              token: token,
              ngrok_port: ngrok_port,
              webhook_pid: webhook_pid,
              max_runtime: max_runtime
            }}

          {:error, error} ->
            IO.puts("❌ Error getting webhook info: #{inspect(error)}")
            cleanup(token, ngrok_port)
            {:stop, :normal}
        end

      {:error, error} ->
        IO.puts("❌ Failed to set webhook: #{inspect(error)}")
        cleanup(token, ngrok_port)
        {:stop, :normal}
    end
  end

  @impl true
  def handle_info(:shutdown, state) do
    IO.puts("\nMaximum runtime of #{state.max_runtime} seconds reached. Stopping bot.")
    {:stop, :normal, state}
  end

  # Add a catch-all handler for port messages from ngrok
  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %{ngrok_port: port} = state) do
    # Just log the ngrok output and continue
    IO.puts("ngrok output: #{line}")
    {:noreply, state}
  end

  # Handle port exit status
  @impl true
  def handle_info({port, {:exit_status, status}}, %{ngrok_port: port} = state) do
    IO.puts("⚠️ ngrok process exited with status #{status}")
    if status != 0 do
      # Abnormal exit, we should stop the GenServer
      {:stop, {:ngrok_exit, status}, state}
    else
      # Normal exit
      {:noreply, state}
    end
  end

  # Add a catch-all handler for other messages
  @impl true
  def handle_info(_msg, state) do
    # Ignore other messages
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    IO.puts("\n🛑 Terminating webhook bot... (reason: #{inspect(reason)})")

    # Perform cleanup
    cleanup(state.token, state.ngrok_port)

    # As a final safety measure, make one more direct webhook deletion call
    # This ensures the webhook is deleted even if the cleanup function had issues
    IO.puts("🔄 Final webhook deletion check...")
    url = "https://api.telegram.org/bot#{state.token}/deleteWebhook"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: %{drop_pending_updates: true}
    }

    case Client.make_request(lens, lens.params) do
      {:ok, true} ->
        IO.puts("✅ Final webhook deletion successful")
      {:error, error} ->
        IO.puts("❌ Final webhook deletion failed: #{inspect(error)}")
    end

    # Give some time for cleanup operations to complete
    :timer.sleep(500)

    :ok
  end

  # Start a webhook server
  defp start_webhook_server(token, port, path) do
    # Start the server with Plug.Cowboy
    Plug.Cowboy.http(TelegramWebhookHandler, [token: token, path: path],
      port: port,
      ref: TelegramWebhookHandler.HTTP
    )
  end

  # Start ngrok and return the public URL
  defp start_ngrok(port) do
    IO.puts("Starting ngrok tunnel to port #{port}...")

    # Start ngrok as a port-forwarded process
    port_args = ["http", Integer.to_string(port)]

    # Add --log=stdout to see ngrok logs
    ngrok_args = port_args ++ ["--log=stdout"]

    # Start ngrok process
    ngrok_port = Port.open({:spawn_executable, find_ngrok_executable()},
      [:binary, :exit_status, {:args, ngrok_args}, {:line, 1024}]
    )

    # Wait for ngrok to start and extract the public URL
    ngrok_url = wait_for_ngrok_url(ngrok_port)

    # Return both the port and the URL
    {ngrok_port, ngrok_url}
  end

  # Find the ngrok executable in PATH
  defp find_ngrok_executable do
    case System.find_executable("ngrok") do
      nil ->
        IO.puts("❌ ngrok executable not found in PATH!")
        IO.puts("Please install ngrok and make sure it's in your PATH")
        System.halt(1)

      path -> path
    end
  end

  # Wait for ngrok to output its public URL
  defp wait_for_ngrok_url(port, timeout \\ 30000) do
    start_time = System.monotonic_time(:millisecond)
    wait_for_ngrok_url_loop(port, start_time, timeout, [])
  end

  defp wait_for_ngrok_url_loop(port, start_time, timeout, lines) do
    receive do
      {^port, {:data, {:eol, line}}} ->
        IO.puts("ngrok output: #{line}")

        # Try to find URL in various formats
        url_patterns = [
          ~r/Forwarding\s+(https:\/\/[a-zA-Z0-9\-\.]+\.ngrok\.io)/,
          ~r/Forwarding\s+(https:\/\/[a-zA-Z0-9\-\.]+\.ngrok-free\.app)/,
          ~r/url=(https:\/\/[a-zA-Z0-9\-\.]+\.ngrok\.io)/,
          ~r/url=(https:\/\/[a-zA-Z0-9\-\.]+\.ngrok-free\.app)/,
          ~r/Web Interface\s+(https:\/\/[a-zA-Z0-9\-\.]+\.ngrok\.io)/,
          ~r/Forwarding\s+.+\s+->\s+http:\/\/localhost:\d+/
        ]

        # Try each pattern
        url = Enum.find_value(url_patterns, fn pattern ->
          case Regex.run(pattern, line) do
            [_, url] -> url
            [match] when pattern == ~r/Forwarding\s+.+\s+->\s+http:\/\/localhost:\d+/ ->
              # Extract URL from the forwarding line
              case Regex.run(~r/(https:\/\/[a-zA-Z0-9\-\.]+\.ngrok(?:-free)?\.app)/, match) do
                [_, extracted_url] -> extracted_url
                _ -> nil
              end
            _ -> nil
          end
        end)

        if url do
          # Found the URL
          IO.puts("\n🌐 NGROK URL FOUND: #{url}")
          IO.puts("🌐 This is the URL that will be registered with Telegram")
          url
        else
          # Check if we have enough lines to try to extract the URL
          updated_lines = [line | lines]

          # Try to find any URL in the collected lines
          all_urls = Enum.flat_map(updated_lines, fn collected_line ->
            Regex.scan(~r/(https:\/\/[a-zA-Z0-9\-\.]+\.ngrok(?:-free)?\.app)/, collected_line)
            |> Enum.map(fn [_, url] -> url end)
          end)

          if length(all_urls) > 0 do
            url = List.first(all_urls)
            IO.puts("\n🌐 NGROK URL FOUND IN COLLECTED OUTPUT: #{url}")
            IO.puts("🌐 This is the URL that will be registered with Telegram")
            url
          else
            # Keep waiting or collecting
            current_time = System.monotonic_time(:millisecond)
            elapsed = current_time - start_time

            if elapsed > timeout do
              IO.puts("❌ Timed out waiting for ngrok to start!")
              System.halt(1)
            else
              wait_for_ngrok_url_loop(port, start_time, timeout, updated_lines)
            end
          end
        end

      {^port, {:exit_status, status}} ->
        IO.puts("❌ ngrok exited with status #{status}!")
        System.halt(1)

      _ ->
        # Ignore other messages
        wait_for_ngrok_url_loop(port, start_time, timeout, lines)
    after
      timeout ->
        IO.puts("❌ Timed out waiting for ngrok to start!")
        System.halt(1)
    end
  end

  # Clean up resources before exiting
  defp cleanup(token, ngrok_port) do
    IO.puts("Cleaning up...")

    # First check if the webhook is actually set
    _webhook_status = check_webhook_status(token)

    # Delete the webhook with retries
    try do
      # First attempt to delete the webhook
      webhook_deleted = case delete_webhook(token) do
        {:ok, true} ->
          IO.puts("✅ Webhook deleted successfully!")
          true
        {:error, error} ->
          IO.puts("❌ Failed to delete webhook: #{inspect(error)}")
          false
      end

      # If the first attempt failed, try again with a different approach
      unless webhook_deleted do
        IO.puts("🔄 Retrying webhook deletion with alternative method...")

        # Try a direct API call with drop_pending_updates
        url = "https://api.telegram.org/bot#{token}/deleteWebhook"

        lens = %{
          url: url,
          method: :post,
          headers: [{"content-type", "application/json"}],
          params: %{drop_pending_updates: true}
        }

        case Client.make_request(lens, lens.params) do
          {:ok, true} ->
            IO.puts("✅ Webhook deleted successfully on retry!")
          {:error, error} ->
            IO.puts("❌ Failed to delete webhook on retry: #{inspect(error)}")
        end

        # Verify webhook is gone by checking webhook info
        case get_webhook_info(token) do
          {:ok, info} ->
            if info["url"] == "" or info["url"] == nil do
              IO.puts("✅ Webhook deletion verified - webhook URL is empty")
            else
              IO.puts("⚠️ WARNING: Webhook still appears to be set to: #{info["url"]}")
              IO.puts("⚠️ You may need to manually delete the webhook before using getUpdates")
            end
          {:error, error} ->
            IO.puts("❌ Error verifying webhook deletion: #{inspect(error)}")
        end
      end
    rescue
      e -> IO.puts("❌ Error during webhook deletion: #{inspect(e)}")
    end

    # Stop the ngrok process
    try do
      if is_port(ngrok_port) and Port.info(ngrok_port) != nil do
        IO.puts("🛑 Stopping ngrok process...")

        # Try to get the OS pid of the ngrok process
        case Port.info(ngrok_port) |> Enum.find(fn {key, value} ->  key == :os_pid end) do
          {:os_pid, os_pid} when is_integer(os_pid) ->
            # On Unix systems, try to send SIGTERM to the process
            case :os.type() do
              {:unix, _} ->
                # Use os_cmd to send a kill signal
                System.cmd("kill", ["-15", Integer.to_string(os_pid)])
                IO.puts("✅ Sent SIGTERM to ngrok process (PID: #{os_pid})")

                # Give it a moment to terminate
                :timer.sleep(100)

                # If it's still running, try SIGKILL
                # Check if process is still running using ps
                {check_output, _} = System.cmd("sh", ["-c", "ps -p #{os_pid} || true"])
                if String.contains?(check_output, Integer.to_string(os_pid)) do
                  System.cmd("kill", ["-9", Integer.to_string(os_pid)])
                  IO.puts("✅ Sent SIGKILL to ngrok process (PID: #{os_pid})")
                end
              _ ->
                # On non-Unix systems, we can't send signals
                :ok
            end
          _ ->
            # If we can't get the OS pid, just continue
            :ok
        end

        # Close the port
        Port.close(ngrok_port)
        IO.puts("✅ Closed ngrok port")

        # For extra safety, try to find and kill any lingering ngrok processes
        case :os.type() do
          {:unix, _} ->
            # Use ps and grep to find ngrok processes
            {output, _} = System.cmd("sh", ["-c", "ps aux | grep ngrok | grep -v grep || true"])

            # Parse the output to find PIDs
            ngrok_pids = output
              |> String.split("\n", trim: true)
              |> Enum.map(fn line ->
                case String.split(line, " ", trim: true) do
                  [_, pid | _] -> pid
                  _ -> nil
                end
              end)
              |> Enum.filter(&(&1 != nil))

            # Kill each process
            Enum.each(ngrok_pids, fn pid ->
              System.cmd("kill", ["-15", pid])
              IO.puts("✅ Sent SIGTERM to lingering ngrok process (PID: #{pid})")

              # Give it a moment to terminate
              :timer.sleep(50)

              # If it's still running, try SIGKILL
              {check_output, _} = System.cmd("sh", ["-c", "ps -p #{pid} || true"])
              if String.contains?(check_output, pid) do
                System.cmd("kill", ["-9", pid])
                IO.puts("✅ Sent SIGKILL to lingering ngrok process (PID: #{pid})")
              end
            end)

          _ ->
            # On non-Unix systems, we can't do this
            :ok
        end

        # As a last resort, try to kill all ngrok processes
        case :os.type() do
          {:unix, _} ->
            System.cmd("sh", ["-c", "killall -9 ngrok || true"])
            IO.puts("✅ Attempted to kill all ngrok processes")
          _ ->
            :ok
        end

        IO.puts("✅ ngrok process stopped")
      end
    rescue
      e -> IO.puts("❌ Error during ngrok cleanup: #{inspect(e)}")
    end

    # Stop the webhook server if it's running
    try do
      Plug.Cowboy.shutdown(TelegramWebhookHandler.HTTP)
      IO.puts("✅ Webhook server stopped")
    rescue
      e -> IO.puts("❌ Error stopping webhook server: #{inspect(e)}")
    end

    IO.puts("Webhook Echo Bot stopped.")
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
    # Create the request parameters with or without reply_to_message_id
    params = if reply_to_message_id do
      %{
        method: "sendMessage",
        chat_id: chat_id,
        text: text,
        reply_to_message_id: reply_to_message_id,
        token: token
      }
    else
      %{
        method: "sendMessage",
        chat_id: chat_id,
        text: text,
        token: token
      }
    end

    # Make the request
    url = "https://api.telegram.org/bot#{token}/sendMessage"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: Map.drop(params, [:url, :method, :token])
    }

    case Client.make_request(lens, lens.params) do
      {:ok, response} ->
        IO.puts("Sent echo reply with message ID: #{response["message_id"]}")

      {:error, error} ->
        IO.puts("Error sending echo reply: #{inspect(error)}")
    end
  end

  # Set a webhook
  defp set_webhook(token, url) do
    # Set additional parameters for the webhook
    _params = %{
      method: "setWebhook",
      url: url,
      max_connections: 40,  # Allow more connections
      drop_pending_updates: false,  # Process pending updates
      allowed_updates: ["message", "edited_message", "channel_post", "edited_channel_post", "callback_query"],
      token: token
    }

    api_url = "https://api.telegram.org/bot#{token}/setWebhook"

    # Create a new params map without dropping the url parameter
    request_params = %{
      url: url,
      max_connections: 40,
      drop_pending_updates: false,
      allowed_updates: ["message", "edited_message", "channel_post", "edited_channel_post", "callback_query"]
    }

    lens = %{
      url: api_url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: request_params
    }

    IO.puts("\n🔗 SETTING WEBHOOK URL: #{url}")
    IO.puts("🔗 API URL: #{api_url}")
    IO.puts("🔗 Parameters: #{inspect(lens.params)}")

    case Client.make_request(lens, lens.params) do
      {:ok, response} ->
        IO.puts("🔗 Webhook set response: #{inspect(response)}")
        {:ok, true}

      {:error, error} ->
        IO.puts("❌ Error setting webhook: #{inspect(error)}")
        {:error, error}
    end
  end

  # Delete a webhook
  defp delete_webhook(token) do
    # Create the request parameters
    _params = %{
      method: "deleteWebhook",
      token: token
    }

    url = "https://api.telegram.org/bot#{token}/deleteWebhook"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: %{}  # Empty map since deleteWebhook doesn't need parameters
    }

    IO.puts("🔄 Deleting webhook...")
    result = Client.make_request(lens, lens.params)

    case result do
      {:ok, true} ->
        # Verify the webhook was actually deleted by checking webhook info
        verify_webhook_deleted(token)
      _ ->
        result
    end
  end

  # Verify that the webhook was actually deleted
  defp verify_webhook_deleted(token) do
    IO.puts("🔍 Verifying webhook deletion...")
    case get_webhook_info(token) do
      {:ok, info} ->
        if info["url"] == "" or info["url"] == nil do
          IO.puts("✅ Webhook deletion verified - webhook URL is empty")
          {:ok, true}
        else
          IO.puts("⚠️ Webhook still appears to be set to: #{info["url"]}")
          IO.puts("🔄 Attempting to delete webhook again...")

          # Try a more forceful deletion with drop_pending_updates
          url = "https://api.telegram.org/bot#{token}/deleteWebhook"

          lens = %{
            url: url,
            method: :post,
            headers: [{"content-type", "application/json"}],
            params: %{drop_pending_updates: true}
          }

          case Client.make_request(lens, lens.params) do
            {:ok, true} ->
              IO.puts("✅ Webhook forcefully deleted")
              {:ok, true}
            {:error, error} ->
              IO.puts("❌ Failed to forcefully delete webhook: #{inspect(error)}")
              {:error, error}
          end
        end
      {:error, error} ->
        IO.puts("❌ Error verifying webhook deletion: #{inspect(error)}")
        {:error, error}
    end
  end

  # Get webhook info
  defp get_webhook_info(token) do
    # Create the request parameters
    _params = %{
      method: "getWebhookInfo",
      token: token
    }

    url = "https://api.telegram.org/bot#{token}/getWebhookInfo"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: %{}  # Empty map since getWebhookInfo doesn't need parameters
    }

    Client.make_request(lens, lens.params)
  end

  # Get bot information
  defp get_me(token) do
    # Create the request parameters
    _params = %{
      method: "getMe",
      token: token
    }

    url = "https://api.telegram.org/bot#{token}/getMe"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: %{}  # Empty map since getMe doesn't need parameters
    }

    Client.make_request(lens, lens.params)
  end

  # Process pending updates manually
  defp process_pending_updates(token) do
    # Get updates with a small timeout
    request_params = %{
      offset: 0,
      timeout: 1,
      limit: 100
    }

    url = "https://api.telegram.org/bot#{token}/getUpdates"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: request_params
    }

    case Client.make_request(lens, lens.params) do
      {:ok, updates} when is_list(updates) and length(updates) > 0 ->
        IO.puts("📥 Received #{length(updates)} updates manually")

        # Process each update
        Enum.each(updates, fn update ->
          IO.puts("Processing update: #{inspect(update)}")

          # Check if this is a message update
          if Map.has_key?(update, "message") do
            message = update["message"]

            # Check if the message has text
            if Map.has_key?(message, "text") do
              # Get message details
              chat_id = message["chat"]["id"]
              message_id = message["message_id"]
              text = message["text"]
              from_user = get_user_name(message["from"])

              IO.puts("\n📩 Received message from #{from_user}: #{text}")

              # Echo the message back
              echo_text = "Echo: #{text}"
              send_message(chat_id, echo_text, message_id, token)
            end
          end
        end)

        # Get the highest update_id to use as the new offset
        new_offset = updates
          |> Enum.map(fn update -> update["update_id"] end)
          |> Enum.max()
          |> Kernel.+(1)  # Add 1 to get the next update

        # Acknowledge updates to clear them
        acknowledge_updates(token, new_offset)

      {:ok, _} ->
        IO.puts("No updates to process manually")

      {:error, error} ->
        IO.puts("Error fetching updates manually: #{inspect(error)}")
    end
  end

  # Acknowledge updates to clear them
  defp acknowledge_updates(token, offset) do
    request_params = %{
      offset: offset,
      timeout: 1,
      limit: 1
    }

    url = "https://api.telegram.org/bot#{token}/getUpdates"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: request_params
    }

    case Client.make_request(lens, lens.params) do
      {:ok, _} ->
        IO.puts("✅ Acknowledged updates up to #{offset - 1}")

      {:error, error} ->
        IO.puts("❌ Error acknowledging updates: #{inspect(error)}")
    end
  end

  # Check webhook status
  defp check_webhook_status(token) do
    IO.puts("🔍 Checking webhook status...")
    case get_webhook_info(token) do
      {:ok, info} ->
        if info["url"] == "" or info["url"] == nil do
          IO.puts("ℹ️ No webhook is currently set")
          :not_set
        else
          IO.puts("ℹ️ Webhook is currently set to: #{info["url"]}")
          :set
        end
      {:error, error} ->
        IO.puts("❌ Error checking webhook status: #{inspect(error)}")
        :unknown
    end
  end
end
