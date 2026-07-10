defmodule LuxAppWeb.AnalyticsLive do
  use LuxAppWeb, :live_view

  alias Lux.Lenses.DefiLlama.GetProtocolTvl

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :fetch_tvl)
    end

    {:ok, assign(socket, protocol: "lido", tvl_data: nil, loading: true, error: nil)}
  end

  @impl true
  def handle_info(:fetch_tvl, socket) do
    case GetProtocolTvl.focus(%{protocol: socket.assigns.protocol}) do
      {:ok, data} ->
        {:noreply, assign(socket, tvl_data: data, loading: false, error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, error: to_string(reason), loading: false, tvl_data: nil)}
    end
  end

  @impl true
  def handle_event("search", %{"protocol" => protocol}, socket) do
    send(self(), :fetch_tvl)
    {:noreply, assign(socket, protocol: protocol, loading: true, error: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8">
      <h1 class="text-3xl font-bold mb-6 text-gray-800 dark:text-white">DeFi Analytics Dashboard</h1>

      <form phx-submit="search" class="mb-8">
        <div class="flex gap-4">
          <input type="text" name="protocol" value={@protocol} placeholder="Enter protocol slug (e.g., lido, aave)" class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 p-2" />
          <button type="submit" class="bg-indigo-600 text-white px-4 py-2 rounded-md hover:bg-indigo-700">Fetch Analytics</button>
        </div>
      </form>

      <%= if @loading do %>
        <div class="flex justify-center py-12">
          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
        </div>
      <% end %>

      <%= if @error do %>
        <div class="bg-red-50 text-red-700 p-4 rounded-md mb-6">
          <p class="font-semibold">Error fetching data:</p>
          <p><%= @error %></p>
        </div>
      <% end %>

      <%= if @tvl_data do %>
        <div class="bg-white dark:bg-gray-800 shadow rounded-lg overflow-hidden">
          <div class="px-4 py-5 sm:p-6">
            <h2 class="text-2xl font-bold text-gray-900 dark:text-white mb-2"><%= @tvl_data.name %> (<%= @tvl_data.symbol %>)</h2>
            <div class="mt-4 grid grid-cols-1 gap-5 sm:grid-cols-2">
              <div class="bg-gray-50 dark:bg-gray-900 overflow-hidden shadow rounded-lg">
                <div class="px-4 py-5 sm:p-6">
                  <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">Current TVL</dt>
                  <dd class="mt-1 text-3xl font-semibold text-indigo-600 dark:text-indigo-400">
                    $<%= Number.Delimit.number_to_delimited(round(@tvl_data.tvl), precision: 0) %>
                  </dd>
                </div>
              </div>
              <%= if map_size(@tvl_data.chain_tvls) > 0 do %>
                <div class="bg-gray-50 dark:bg-gray-900 overflow-hidden shadow rounded-lg">
                  <div class="px-4 py-5 sm:p-6">
                    <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">Chains</dt>
                    <dd class="mt-1 text-sm text-gray-900 dark:text-gray-100">
                      <%= for {chain, tvl} <- @tvl_data.chain_tvls do %>
                        <div class="flex justify-between py-1">
                          <span class="font-medium"><%= chain %></span>
                          <span>$<%= Number.Delimit.number_to_delimited(round(tvl), precision: 0) %></span>
                        </div>
                      <% end %>
                    </dd>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
