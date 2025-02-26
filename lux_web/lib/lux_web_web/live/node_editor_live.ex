defmodule LuxWebWeb.NodeEditorLive do
  use LuxWebWeb, :live_view
  require Logger

  @node_types %{
    "agent" => %{
      label: "Agent",
      description: "An autonomous agent that can perform tasks",
      color: "#4ade80"
    },
    "prism" => %{
      label: "Prism",
      description: "Processes and transforms data",
      color: "#60a5fa"
    },
    "lens" => %{
      label: "Lens",
      description: "Retrieves data from external sources",
      color: "#c084fc"
    },
    "beam" => %{
      label: "Beam",
      description: "Executes actions in external systems",
      color: "#fb923c"
    }
  }

  def mount(_params, _session, socket) do
    nodes = [
      %{
        "id" => "agent-1",
        "type" => "agent",
        "position" => %{"x" => 400, "y" => 200},
        "data" => %{
          "label" => "Ultimate Assistant",
          "description" => "Tools Agent",
          "goal" => "Help users with various tasks",
          "components" => [
            %{"id" => "comp-1", "type" => "prism", "name" => "Chat Model", "label" => "Chat Model"},
            %{"id" => "comp-2", "type" => "lens", "name" => "Memory", "label" => "Memory"},
            %{"id" => "comp-3", "type" => "beam", "name" => "Tool", "label" => "Tool"}
          ]
        }
      }
    ]

    edges = []

    {:ok,
     socket
     |> assign(:nodes, nodes)
     |> assign(:edges, edges)
     |> assign(:node_types, @node_types)
     |> assign(:selected_node, nil)
     |> assign(:dragging_node, nil)
     |> assign(:drawing_edge, nil)}
  end

  def handle_event("node_selected", %{"node_id" => node_id}, socket) do
    selected_node = Enum.find(socket.assigns.nodes, &(&1["id"] == node_id))
    {:noreply, assign(socket, :selected_node, selected_node)}
  end

  def handle_event("canvas_clicked", _params, socket) do
    {:noreply, assign(socket, :selected_node, nil)}
  end

  def handle_event("node_dragged", %{"node_id" => node_id, "x" => x, "y" => y}, socket) do
    nodes = Enum.map(socket.assigns.nodes, fn node ->
      if node["id"] == node_id do
        %{node | "position" => %{"x" => x, "y" => y}}
      else
        node
      end
    end)
    {:noreply, assign(socket, :nodes, nodes)}
  end

  def handle_event("mousedown", %{"node_id" => node_id, "clientX" => x, "clientY" => y}, socket) do
    # Find the node's current position
    node = Enum.find(socket.assigns.nodes, &(&1["id"] == node_id))
    original_position = node["position"]

    # Store the dragging state with mouse offset from node position
    mouse_offset_x = x - original_position["x"]
    mouse_offset_y = y - original_position["y"]

    Logger.debug(%{
      node_id: node_id,
      original_position: original_position,
      mouse_offset_x: mouse_offset_x,
      mouse_offset_y: mouse_offset_y
    })

    {:noreply, assign(socket, :dragging_node, %{
      "id" => node_id,
      "mouse_offset_x" => mouse_offset_x,
      "mouse_offset_y" => mouse_offset_y,
      "original_position" => original_position
    })}
  end

  def handle_event("mousemove", %{"clientX" => x, "clientY" => y}, socket) do
    case socket.assigns.dragging_node do
      %{"id" => node_id, "mouse_offset_x" => offset_x, "mouse_offset_y" => offset_y, "original_position" => original_position} ->
        # Calculate new position by subtracting the initial offset
        new_x = x - offset_x
        new_y = y - offset_y

        # Snap to grid (20px grid)
        snapped_x = round(new_x / 20) * 20
        snapped_y = round(new_y / 20) * 20

        # Apply bounds constraints
        bounded_x = max(0, min(snapped_x, 1720))  # 1920 - node width (200)
        bounded_y = max(0, min(snapped_y, 980))   # 1080 - node height (100)

        Logger.debug(%{
          node_id: node_id,
          raw: %{x: x, y: y},
          calculated: %{new_x: new_x, new_y: new_y},
          snapped: %{snapped_x: snapped_x, snapped_y: snapped_y},
          bounded: %{bounded_x: bounded_x, bounded_y: bounded_y}
        })

        nodes = Enum.map(socket.assigns.nodes, fn node ->
          if node["id"] == node_id do
            %{node | "position" => %{"x" => bounded_x, "y" => bounded_y}}
          else
            node
          end
        end)
        {:noreply, assign(socket, :nodes, nodes)}
      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("mouseup", _params, socket) do
    # Clear the dragging state
    case socket.assigns.dragging_node do
      %{"id" => node_id} ->
        node = Enum.find(socket.assigns.nodes, &(&1["id"] == node_id))
        Logger.debug(%{
          node_id: node_id,
          final_position: %{x: node["position"]["x"], y: node["position"]["y"]}
        })
      _ -> :ok
    end

    {:noreply, assign(socket, :dragging_node, nil)}
  end

  def handle_event("keydown", %{"key" => "Escape"}, socket) do
    case socket.assigns.dragging_node do
      %{"id" => node_id, "original_position" => original_position} ->
        # Revert the node to its original position
        nodes = Enum.map(socket.assigns.nodes, fn node ->
          if node["id"] == node_id do
            %{node | "position" => original_position}
          else
            node
          end
        end)
        {:noreply, socket |> assign(:nodes, nodes) |> assign(:dragging_node, nil)}
      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("edge_started", %{"source_id" => source_id}, socket) do
    {:noreply, assign(socket, :drawing_edge, %{"source_id" => source_id})}
  end

  def handle_event("edge_completed", %{"target_id" => target_id}, socket) do
    case socket.assigns.drawing_edge do
      %{"source_id" => source_id} when not is_nil(source_id) ->
        edge_id = "edge-#{source_id}-#{target_id}"
        new_edge = %{
          "id" => edge_id,
          "source" => source_id,
          "target" => target_id,
          "type" => "signal"
        }
        edges = [new_edge | socket.assigns.edges]
        {:noreply, socket |> assign(:edges, edges) |> assign(:drawing_edge, nil)}
      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("edge_cancelled", _params, socket) do
    {:noreply, assign(socket, :drawing_edge, nil)}
  end

  def handle_event("node_added", %{"node" => node}, socket) do
    nodes = [node | socket.assigns.nodes]
    {:noreply, assign(socket, :nodes, nodes)}
  end

  def handle_event("node_removed", %{"id" => node_id}, socket) do
    nodes = Enum.reject(socket.assigns.nodes, fn node -> node["id"] == node_id end)
    {:noreply, assign(socket, :nodes, nodes)}
  end

  def handle_event("update_node", %{"node" => node_params}, socket) do
    nodes = Enum.map(socket.assigns.nodes, fn node ->
      if node["id"] == node_params["id"] do
        # Update the node's data while preserving other fields
        %{node | "data" => Map.merge(node["data"], node_params["data"])}
      else
        node
      end
    end)

    # Update both nodes list and selected node
    selected_node = Enum.find(nodes, &(&1["id"] == node_params["id"]))
    {:noreply, socket |> assign(:nodes, nodes) |> assign(:selected_node, selected_node)}
  end

  def handle_event("update_property", %{"key" => "Enter", "value" => value, "field" => field} = params, socket) do
    if (params["metaKey"] == true or params["ctrlKey"] == true) and socket.assigns.selected_node do
      nodes = Enum.map(socket.assigns.nodes, fn node ->
        if node["id"] == socket.assigns.selected_node["id"] do
          put_in(node, ["data", field], value)
        else
          node
        end
      end)

      # Update both nodes list and selected node
      selected_node = Enum.find(nodes, &(&1["id"] == socket.assigns.selected_node["id"]))
      {:noreply, socket |> assign(:nodes, nodes) |> assign(:selected_node, selected_node)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_property", _params, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex h-screen w-screen bg-gray-900 text-white overflow-hidden">
      <!-- Component Palette -->
      <div class="w-64 border-r border-gray-700 p-4 overflow-y-auto">
        <h2 class="text-xl font-bold mb-4">Components</h2>
        <div class="space-y-2">
          <%= for {type, info} <- @node_types do %>
            <div
              class="p-3 bg-gray-800 rounded-md cursor-move border border-gray-700 hover:border-blue-500 transition-colors"
              draggable="true"
              phx-hook="DraggableNode"
              id={"draggable-#{type}"}
              data-type={type}
            >
              <div class="flex items-center">
                <div class={"w-8 h-8 rounded-full mr-2 flex items-center justify-center"} style={"background: #{info.color}20"}>
                  <div class={"w-5 h-5"} style={"background: #{info.color}"}></div>
                </div>
                <div>
                  <div class="font-medium"><%= info.label %></div>
                  <div class="text-xs text-gray-400"><%= info.description %></div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Node Editor Canvas -->
      <div class="flex-1 relative" id="node-editor-canvas" phx-hook="NodeCanvas" phx-click="canvas_clicked">
        <svg class="w-full h-full absolute inset-0">
          <!-- Grid Background -->
          <defs>
            <pattern id="grid" width="16" height="16" patternUnits="userSpaceOnUse">
              <path d="M 16 0 L 0 0 0 16" fill="none" stroke="#333" stroke-width="0.5"/>
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#grid)"/>

          <!-- Edges -->
          <%= for edge <- @edges do %>
            <g class="edge">
              <!-- We'll implement the edge path calculation in JS -->
              <path
                class="edge-path"
                data-edge-id={edge["id"]}
                data-source={edge["source"]}
                data-target={edge["target"]}
                stroke="#666"
                stroke-width="2"
                fill="none"
              />
            </g>
          <% end %>

          <!-- Drawing Edge (if any) -->
          <%= if @drawing_edge do %>
            <path
              id="drawing-edge"
              stroke="#666"
              stroke-width="2"
              stroke-dasharray="5,5"
              fill="none"
            />
          <% end %>

          <!-- Nodes -->
          <%= for node <- @nodes do %>
            <g
              class="node"
              transform={"translate(#{node["position"]["x"]},#{node["position"]["y"]})"}
              phx-click="node_selected"
              phx-value-node_id={node["id"]}
              data-node-id={node["id"]}
              phx-hook="NodeDraggable"
              id={"node-#{node["id"]}"}
            >
              <rect
                width="200"
                height="100"
                rx="5"
                ry="5"
                fill={@node_types[node["type"]].color <> "20"}
                stroke={@node_types[node["type"]].color}
                stroke-width="2"
              />
              <text x="10" y="30" fill="white" font-weight="bold"><%= node["data"]["label"] %></text>
              <text x="10" y="50" fill="#999" font-size="12"><%= node["data"]["description"] %></text>

              <!-- Node Ports -->
              <circle class="port input" cx="0" cy="50" r="5" fill={@node_types[node["type"]].color}/>
              <circle class="port output" cx="200" cy="50" r="5" fill={@node_types[node["type"]].color}/>
            </g>
          <% end %>
        </svg>
      </div>

      <!-- Properties Panel -->
      <div class="w-64 border-l border-gray-700 p-4 overflow-y-auto">
        <h2 class="text-xl font-bold mb-4">Properties</h2>
        <%= if @selected_node do %>
          <form phx-submit="update_node">
            <input type="hidden" name="node[id]" value={@selected_node["id"]} />
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-400 mb-1">Name</label>
                <input
                  type="text"
                  name="node[data][label]"
                  value={@selected_node["data"]["label"]}
                  class="w-full bg-gray-800 border border-gray-700 rounded-md px-3 py-2 text-sm"
                  phx-keydown="update_property"
                  phx-value-field="label"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-400 mb-1">Description</label>
                <textarea
                  name="node[data][description]"
                  class="w-full bg-gray-800 border border-gray-700 rounded-md px-3 py-2 text-sm"
                  rows="3"
                  phx-keydown="update_property"
                  phx-value-field="description"
                ><%= @selected_node["data"]["description"] %></textarea>
              </div>
              <%= if @selected_node["type"] == "agent" do %>
                <div>
                  <label class="block text-sm font-medium text-gray-400 mb-1">Goal</label>
                  <textarea
                    name="node[data][goal]"
                    class="w-full bg-gray-800 border border-gray-700 rounded-md px-3 py-2 text-sm"
                    rows="3"
                    phx-keydown="update_property"
                    phx-value-field="goal"
                  ><%= @selected_node["data"]["goal"] %></textarea>
                </div>
              <% end %>
              <button
                type="submit"
                class="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-md"
              >
                Update
              </button>
            </div>
          </form>
        <% else %>
          <div class="text-gray-400 text-sm">
            Select a node to view and edit its properties.
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
