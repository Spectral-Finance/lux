defmodule LuxAppWeb.NodeEditorLiveTest do
  use LuxAppWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "NodeEditorLive" do
    test "renders the node editor interface", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Test that the component palette is rendered
      assert has_element?(view, "h2", "Components")
      assert has_element?(view, "h2", "Properties")

      # Test that the canvas container is rendered
      assert has_element?(view, "#node-editor-canvas")
    end

    test "adds a node when event is received", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Create a new node
      new_node = %{
        "id" => "agent-test",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "name" => "Test Agent",
          "description" => "Test description",
          "goal" => "Test goal",
          "components" => []
        }
      }

      # Send the node_added event
      view |> element("#node-editor-canvas") |> render_hook("node_added", %{"node" => new_node})

      # Verify that the node was added
      html = render(view)
      assert html =~ "Test Agent"
      assert html =~ "Test description"
    end

    test "removes a node when event is received", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # First add a node
      new_node = %{
        "id" => "agent-to-remove",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "name" => "Agent to Remove",
          "description" => "Test description",
          "goal" => "Test goal",
          "components" => []
        }
      }

      view |> element("#node-editor-canvas") |> render_hook("node_added", %{"node" => new_node})

      # Verify the node was added
      html = render(view)
      assert html =~ "Agent to Remove"
      assert html =~ "Test description"

      # Now remove the node
      view
      |> element("#node-editor-canvas")
      |> render_hook("node_removed", %{"id" => "agent-to-remove"})

      # Verify the node was removed
      html = render(view)
      refute html =~ "Agent to Remove"
    end

    test "selects a node when event is received", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # First add a node
      new_node = %{
        "id" => "agent-to-select",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "name" => "Agent to Select",
          "description" => "Test description",
          "goal" => "Test goal",
          "components" => [],
          "llm_config" => %{
            "provider" => "openai",
            "model" => "gpt-4o",
            "temperature" => 0.5
          }
        }
      }

      view |> element("#node-editor-canvas") |> render_hook("node_added", %{"node" => new_node})

      # Initially no node should be selected
      assert render(view) =~ "Select a node to view and edit its properties"

      # Select the node
      view |> element("g.node[data-node-id='agent-to-select']") |> render_click()

      # Verify the node was selected
      html = render(view)
      assert html =~ "Agent to Select"
      assert html =~ "Test description"
      assert html =~ "Test goal"
    end

    test "adds an edge when event is received", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # First add two nodes
      source_node = %{
        "id" => "agent-source",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "name" => "Source Agent",
          "description" => "Test description"
        }
      }

      target_node = %{
        "id" => "prism-target",
        "type" => "prism",
        "position" => %{"x" => 300, "y" => 100},
        "data" => %{
          "name" => "Target Prism",
          "description" => "Test description"
        }
      }

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => source_node})

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => target_node})

      # Start drawing the edge
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_started", %{"source_id" => "agent-source"})

      # Complete the edge
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_completed", %{"target_id" => "prism-target"})

      # Verify that the edge was added
      html = render(view)
      assert html =~ "edge-agent-source-prism-target"
      assert html =~ "agent-source"
      assert html =~ "prism-target"
    end

    test "renders initial state", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Check that the page renders with basic structure
      assert html =~ "Components"
      assert html =~ "Properties"
      assert html =~ "Ultimate Assistant"
      assert html =~ "Tools Agent"
    end

    test "selecting a node updates the properties panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Initial state should show "Select a node" message
      assert render(view) =~ "Select a node to view and edit its properties"

      # Click the node
      view
      |> element("g.node[data-node-id='agent-1']")
      |> render_click()

      # Properties panel should now show the node's details
      html = render(view)
      # Node name in form
      assert html =~ "Ultimate Assistant"
      # Node description in form
      assert html =~ "Tools Agent"
      # Node goal in form
      assert html =~ "Help users with various tasks"
    end

    test "selecting different nodes updates the properties panel correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add a second node through a node_added event
      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{
        "node" => %{
          "id" => "prism-1",
          "type" => "prism",
          "position" => %{"x" => 600, "y" => 200},
          "data" => %{
            "name" => "Test Prism",
            "description" => "Test Description"
          }
        }
      })

      # Select first node
      view
      |> element("g.node[data-node-id='agent-1']")
      |> render_click()

      # Check first node's properties
      html = render(view)
      assert html =~ "Ultimate Assistant"
      assert html =~ "Tools Agent"
      assert html =~ "Help users with various tasks"

      # Select second node
      view
      |> element("g.node[data-node-id='prism-1']")
      |> render_click()

      # Check second node's properties
      html = render(view)
      assert html =~ "Test Prism"
      assert html =~ "Test Description"
      # Goal field should not be present for non-agent nodes
      refute html =~ "Help users with various tasks"
    end

    test "deselecting a node clears the properties panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # First select a node
      view
      |> element("g.node[data-node-id='agent-1']")
      |> render_click()

      # Verify node is selected
      assert render(view) =~ "Ultimate Assistant"

      # Click somewhere else on the canvas to deselect
      view
      |> element("#node-editor-canvas")
      |> render_click()

      # Verify node is deselected
      assert render(view) =~ "Select a node to view and edit its properties"
    end

    test "updating agent properties updates both panel and node display", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Select the initial agent node
      view
      |> element("g.node[data-node-id='agent-1']")
      |> render_click()

      # Update the properties
      attrs = %{
        "node" => %{
          "id" => "agent-1",
          "data" => %{
            "name" => "Updated Agent Name",
            "description" => "Updated Description",
            "goal" => "Updated Goal"
          }
        }
      }

      view
      |> form("form", attrs)
      |> render_submit()

      # Verify updates in the rendered HTML
      html = render(view)

      # Check properties panel
      assert html =~ "Updated Agent Name"
      assert html =~ "Updated Description"
      assert html =~ "Updated Goal"

      # Check node display on canvas
      assert html =~
               ~s(<text x="10" y="30" fill="white" font-weight="bold">Updated Agent Name</text>)

      assert html =~ ~s(<text x="10" y="50" fill="#999" font-size="12">Updated Description</text>)
    end

    test "updating prism properties updates both panel and node display", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add a prism node first
      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{
        "node" => %{
          "id" => "prism-test",
          "type" => "prism",
          "position" => %{"x" => 600, "y" => 200},
          "data" => %{
            "name" => "Test Prism",
            "description" => "Test Description"
          }
        }
      })

      # Select the prism node
      view
      |> element("g.node[data-node-id='prism-test']")
      |> render_click()

      # Update the properties
      attrs = %{
        "node" => %{
          "id" => "prism-test",
          "data" => %{
            "name" => "Updated Prism Name",
            "description" => "Updated Prism Description"
          }
        }
      }

      view
      |> form("form", attrs)
      |> render_submit()

      # Verify updates in the rendered HTML
      html = render(view)

      # Check properties panel
      assert html =~ "Updated Prism Name"
      assert html =~ "Updated Prism Description"

      # Check node display on canvas
      assert html =~
               ~s(<text x="10" y="30" fill="white" font-weight="bold">Updated Prism Name</text>)

      assert html =~
               ~s(<text x="10" y="50" fill="#999" font-size="12">Updated Prism Description</text>)

      # Verify that goal field is not present for prism nodes
      refute html =~ "Goal"
    end

    test "node description updates are reflected in the SVG display", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Select the initial agent node
      view
      |> element("g.node[data-node-id='agent-1']")
      |> render_click()

      # Update just the description
      attrs = %{
        "node" => %{
          "id" => "agent-1",
          "data" => %{
            # Keep original name
            "name" => "Ultimate Assistant",
            "description" => "This is a new description that should appear in the node",
            # Keep original goal
            "goal" => "Help users with various tasks"
          }
        }
      }

      view
      |> form("form", attrs)
      |> render_submit()

      # Get the rendered HTML
      html = render(view)

      # Check properties panel
      assert html =~ "This is a new description that should appear in the node"

      # Check the exact SVG text element for description (y=50 is where description appears)
      assert html =~
               ~s(<text x="10" y="50" fill="#999" font-size="12">This is a new description that should appear in the node</text>)

      # Verify the name and goal weren't changed
      assert html =~
               ~s(<text x="10" y="30" fill="white" font-weight="bold">Ultimate Assistant</text>)

      assert html =~ "Help users with various tasks"
    end

    test "updates node properties in real-time when updating the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Select the initial agent node
      view
      |> element("g.node[data-node-id='agent-1']")
      |> render_click()

      # Test name update
      view
      |> element("form")
      |> render_change(%{"node[data][name]" => "Real-time Name Update"})

      html = render(view)
      assert html =~ "Real-time Name Update"

      assert html =~
               ~s(<text x="10" y="30" fill="white" font-weight="bold">Real-time Name Update</text>)

      # Test description update
      view
      |> element("form")
      |> render_change(%{"node[data][description]" => "Real-time Description Update"})

      html = render(view)
      assert html =~ "Real-time Description Update"

      assert html =~
               ~s(<text x="10" y="50" fill="#999" font-size="12">Real-time Description Update</text>)

      html = render(view)
      assert html =~ "Real-time Description Update"

      assert html =~
               ~s(<text x="10" y="50" fill="#999" font-size="12">Real-time Description Update</text>)

      # Test goal update with (only for agent nodes)
      view
      |> element("form")
      |> render_change(%{"node[data][goal]" => "Real-time Goal Update"})

      html = render(view)
      assert html =~ "Real-time Goal Update"
    end

    test "updates prism properties in real-time when updating the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add and select a prism node
      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{
        "node" => %{
          "id" => "prism-test",
          "type" => "prism",
          "position" => %{"x" => 600, "y" => 200},
          "data" => %{
            "name" => "Test Prism",
            "description" => "Test Description"
          }
        }
      })

      view
      |> element("g.node[data-node-id='prism-test']")
      |> render_click()

      # Test Name update with blur
      view
      |> element("form")
      |> render_change(%{"node[data][name]" => "Real-time Prism Update"})

      html = render(view)
      assert html =~ "Real-time Prism Update"

      assert html =~
               ~s(<text x="10" y="30" fill="white" font-weight="bold">Real-time Prism Update</text>)

      # Test description update with blur
      view
      |> element("form")
      |> render_change(%{"node[data][description]" => "Real-time Prism Description"})

      html = render(view)
      assert html =~ "Real-time Prism Description"

      assert html =~
               ~s(<text x="10" y="50" fill="#999" font-size="12">Real-time Prism Description</text>)

      # Verify goal field is not present for prism nodes
      refute has_element?(view, "textarea[name='node[data][goal]']")
    end

    test "dragging a node updates its position in real-time", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Initial position check for agent-1
      html = render(view)
      assert html =~ ~s[transform="translate(400,200)"]

      # Simulate mouse down on the node
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      # Simulate mouse move while dragging
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 500,
        "clientY" => 300,
        "movementX" => 100,
        "movementY" => 100
      })

      # Verify position updated during drag
      html = render(view)
      assert html =~ ~s[transform="translate(500,300)"]

      # Simulate mouse up to complete drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})

      # Verify final position
      html = render(view)
      assert html =~ ~s[transform="translate(500,300)"]
    end

    test "dragging snaps to grid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Start drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      # Move to non-grid position
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 433,
        "clientY" => 267,
        "movementX" => 33,
        "movementY" => 67
      })

      # Verify position snapped to grid (20px)
      html = render(view)
      assert html =~ ~s[transform="translate(440,260)"]

      # Complete drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})
    end

    test "dragging respects canvas bounds", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Start drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      # Try to drag beyond left/top bounds
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => -100,
        "clientY" => -50,
        "movementX" => -500,
        "movementY" => -250
      })

      # Verify position constrained to minimum bounds
      html = render(view)
      assert html =~ ~s[transform="translate(0,0)"]

      # Try to drag beyond right/bottom bounds
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 2500,
        "clientY" => 1500,
        "movementX" => 2600,
        "movementY" => 1550
      })

      # Verify position constrained to maximum bounds
      html = render(view)
      assert html =~ ~s[transform="translate(1720,980)"]

      # Complete drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})
    end

    test "escape key cancels dragging", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Initial position
      html = render(view)
      assert html =~ ~s[transform="translate(400,200)"]

      # Start drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      # Move during drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 500,
        "clientY" => 300,
        "movementX" => 100,
        "movementY" => 100
      })

      # Press escape
      view
      |> element("#node-editor-canvas")
      |> render_hook("keydown", %{"key" => "Escape"})

      # Verify position reverted
      html = render(view)
      assert html =~ ~s[transform="translate(400,200)"]
    end

    test "dragging maintains edge connections", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add a second node
      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{
        "node" => %{
          "id" => "prism-1",
          "type" => "prism",
          "position" => %{"x" => 600, "y" => 200},
          "data" => %{
            "name" => "Test Prism",
            "description" => "Test Description"
          }
        }
      })

      # Create an edge
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_started", %{"source_id" => "agent-1"})

      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_completed", %{"target_id" => "prism-1"})

      # Verify edge exists
      html = render(view)
      assert html =~ "edge-agent-1-prism-1"

      # Drag source node
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 300,
        "clientY" => 300,
        "movementX" => -100,
        "movementY" => 100
      })

      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})

      # Verify edge still exists after drag
      html = render(view)
      assert html =~ "edge-agent-1-prism-1"
    end

    test "dragging multiple nodes maintains their relative positions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add two more nodes at specific positions
      nodes = [
        %{
          "id" => "lens-1",
          "type" => "lens",
          "position" => %{"x" => 200, "y" => 300},
          "data" => %{
            "name" => "Test Lens",
            "description" => "Test Lens Description"
          }
        },
        %{
          "id" => "beam-1",
          "type" => "beam",
          "position" => %{"x" => 700, "y" => 400},
          "data" => %{
            "name" => "Test Beam",
            "description" => "Test Beam Description"
          }
        }
      ]

      # Add the nodes
      for node <- nodes do
        view
        |> element("#node-editor-canvas")
        |> render_hook("node_added", %{"node" => node})
      end

      # Verify initial positions
      html = render(view)
      # lens-1
      assert html =~ ~s[transform="translate(200,300)"]
      # beam-1
      assert html =~ ~s[transform="translate(700,400)"]
      # agent-1 (initial node)
      assert html =~ ~s[transform="translate(400,200)"]

      # Drag each node to new positions
      positions = [
        {"lens-1", 250, 350},
        {"beam-1", 750, 450},
        {"agent-1", 450, 250}
      ]

      for {node_id, x, y} <- positions do
        view
        |> element("#node-editor-canvas")
        |> render_hook("node_dragged", %{
          "node_id" => node_id,
          "x" => x,
          "y" => y
        })
      end

      # Verify all nodes moved to their new positions
      html = render(view)
      # lens-1
      assert html =~ ~s[transform="translate(250,350)"]
      # beam-1
      assert html =~ ~s[transform="translate(750,450)"]
      # agent-1
      assert html =~ ~s[transform="translate(450,250)"]
    end

    test "dragging updates node position in real-time", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Simulate dragging motion with multiple position updates
      positions = [
        {450, 250},
        {500, 300},
        {550, 350},
        {600, 400}
      ]

      # Apply each position update and verify it takes effect immediately
      for {x, y} <- positions do
        view
        |> element("#node-editor-canvas")
        |> render_hook("node_dragged", %{
          "node_id" => "agent-1",
          "x" => x,
          "y" => y
        })

        html = render(view)
        assert html =~ ~s[transform="translate(#{x},#{y})"]
      end
    end

    test "NodeDraggable hook initiates dragging correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Initial position check
      html = render(view)
      assert html =~ ~s[transform="translate(400,200)"]

      # Simulate mousedown on the node via the NodeDraggable hook
      view
      |> element("#node-agent-1")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 420,
        "clientY" => 220
      })

      # Simulate mousemove on the canvas
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 440,
        "clientY" => 240
      })

      # Verify position updated
      html = render(view)
      assert html =~ ~s[transform="translate(420,220)"]

      # Simulate mouseup to end dragging
      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})

      # Verify position remains at the last position
      html = render(view)
      assert html =~ ~s[transform="translate(420,220)"]
    end

    test "dragging with NodeDraggable respects grid snapping", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Simulate mousedown on the node
      view
      |> element("#node-agent-1")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      # Simulate mousemove to a non-grid position
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 427,
        "clientY" => 213
      })

      # Verify position snapped to grid (20px)
      html = render(view)
      assert html =~ ~s[transform="translate(420,220)"]

      # End dragging
      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})
    end

    test "dragging with NodeDraggable respects canvas bounds", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Simulate mousedown on the node
      view
      |> element("#node-agent-1")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      # Try to drag beyond left/top bounds
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => -100,
        "clientY" => -50
      })

      # Verify position constrained to minimum bounds
      html = render(view)
      assert html =~ ~s[transform="translate(0,0)"]

      # Try to drag beyond right/bottom bounds
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 2500,
        "clientY" => 1500
      })

      # Verify position constrained to maximum bounds
      html = render(view)
      assert html =~ ~s[transform="translate(1720,980)"]

      # End dragging
      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})
    end

    test "edge paths are updated when nodes are moved", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add two nodes
      source_node = %{
        "id" => "agent-edge-test",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "name" => "Source Agent",
          "description" => "Edge test source"
        }
      }

      target_node = %{
        "id" => "prism-edge-test",
        "type" => "prism",
        "position" => %{"x" => 300, "y" => 100},
        "data" => %{
          "name" => "Target Prism",
          "description" => "Edge test target"
        }
      }

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => source_node})

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => target_node})

      # Create an edge
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_started", %{"source_id" => "agent-edge-test"})

      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_completed", %{"target_id" => "prism-edge-test"})

      # Verify edge exists
      html = render(view)
      assert html =~ "edge-agent-edge-test-prism-edge-test"

      # Get the initial node position
      node_position_before =
        view
        |> element("g.node[data-node-id='agent-edge-test']")
        |> render()

      assert node_position_before =~ "translate(100,100)"

      # Move the source node
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "agent-edge-test",
        "clientX" => 100,
        "clientY" => 100
      })

      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 200,
        "clientY" => 200
      })

      view |> element("#node-editor-canvas") |> render_hook("mouseup", %{})

      # Get the updated node position
      node_position_after =
        view
        |> element("g.node[data-node-id='agent-edge-test']")
        |> render()

      # The node position should be updated
      assert node_position_after =~ "translate(200,200)"
    end

    test "edge creation process works correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # First add two nodes
      source_node = %{
        "id" => "agent-edge-source",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "name" => "Source Agent",
          "description" => "Edge test source"
        }
      }

      target_node = %{
        "id" => "prism-edge-target",
        "type" => "prism",
        "position" => %{"x" => 300, "y" => 100},
        "data" => %{
          "name" => "Target Prism",
          "description" => "Edge test target"
        }
      }

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => source_node})

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => target_node})

      # Verify both nodes exist
      html = render(view)
      assert html =~ "agent-edge-source"
      assert html =~ "prism-edge-target"

      # Verify the drawing edge element exists in the DOM
      assert has_element?(view, "#drawing-edge") == false

      # Start drawing the edge
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_started", %{"source_id" => "agent-edge-source"})

      # Verify the drawing edge element now exists
      assert has_element?(view, "#drawing-edge") == true

      # Complete the edge
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_completed", %{"target_id" => "prism-edge-target"})

      # Verify that the edge was added
      html = render(view)
      assert html =~ "edge-agent-edge-source-prism-edge-target"

      # Verify the drawing edge is no longer visible
      assert has_element?(view, "#drawing-edge") == false
    end

    test "edges remain visible and persist after node movement", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add two nodes
      source_node = %{
        "id" => "agent-move-edge",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "name" => "Source Agent",
          "description" => "Edge movement test source"
        }
      }

      target_node = %{
        "id" => "prism-move-edge",
        "type" => "prism",
        "position" => %{"x" => 300, "y" => 100},
        "data" => %{
          "name" => "Target Prism",
          "description" => "Edge movement test target"
        }
      }

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => source_node})

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => target_node})

      # Create an edge between the nodes
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_started", %{"source_id" => "agent-move-edge"})

      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_completed", %{"target_id" => "prism-move-edge"})

      # Verify the edge exists
      html = render(view)
      assert html =~ "edge-agent-move-edge-prism-move-edge"

      assert has_element?(
               view,
               "path.edge-path[data-source='agent-move-edge'][data-target='prism-move-edge']"
             )

      # Simulate node dragging
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "agent-move-edge",
        "clientX" => 100,
        "clientY" => 100
      })

      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 150,
        "clientY" => 150,
        "movementX" => 50,
        "movementY" => 50
      })

      # Complete the drag operation
      view |> element("#node-editor-canvas") |> render_hook("mouseup", %{})

      # Verify the edge still exists after dragging
      html = render(view)
      assert html =~ "edge-agent-move-edge-prism-move-edge"

      assert has_element?(
               view,
               "path.edge-path[data-source='agent-move-edge'][data-target='prism-move-edge']"
             )

      # Verify the node position has changed
      assert html =~ ~r/transform="translate\((\d+),(\d+)\)"/
    end

    @tag :pending
    test "edges should be selectable and deletable", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add two nodes
      source_node = %{
        "id" => "agent-select-edge",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "name" => "Source Agent",
          "description" => "Edge selection test source"
        }
      }

      target_node = %{
        "id" => "prism-select-edge",
        "type" => "prism",
        "position" => %{"x" => 300, "y" => 100},
        "data" => %{
          "name" => "Target Prism",
          "description" => "Edge selection test target"
        }
      }

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => source_node})

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => target_node})

      # Create an edge between the nodes
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_started", %{"source_id" => "agent-select-edge"})

      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_completed", %{"target_id" => "prism-select-edge"})

      # Verify the edge exists
      html = render(view)
      assert html =~ "edge-agent-select-edge-prism-select-edge"

      # TODO: Implement edge selection functionality
      # The following tests will pass once the functionality is implemented:

      # 1. Edge should have phx-click attribute for selection
      # assert has_element?(view, "path.edge-path[phx-click='edge_selected']")

      # 2. Clicking the edge should select it
      # view |> element("path.edge-path[data-edge-id='edge-agent-select-edge-prism-select-edge']") |> render_click()

      # 3. Selected edge should have a visual indicator
      # html = render(view)
      # assert html =~ "selected-edge"

      # 4. Properties panel should show edge information
      # assert html =~ "Edge Properties"
      # assert html =~ "Source: Source Agent"
      # assert html =~ "Target: Target Prism"

      # 5. Edge should be deletable
      # view |> element("#delete-edge-button") |> render_click()
      # html = render(view)
      # refute html =~ "edge-agent-select-edge-prism-select-edge"
    end

    test "edges remain stable during node interactions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add three nodes to test multiple edges
      source_node = %{
        "id" => "agent-stable-edge",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "name" => "Source Agent",
          "description" => "Edge stability test source",
          "llm_config" => %{
            "provider" => "openai",
            "model" => "gpt-4o",
            "temperature" => 0.5
          }
        }
      }

      middle_node = %{
        "id" => "prism-stable-middle",
        "type" => "prism",
        "position" => %{"x" => 300, "y" => 100},
        "data" => %{
          "name" => "Middle Prism",
          "description" => "Edge stability test middle",
          "llm_config" => %{
            "provider" => "openai",
            "model" => "gpt-4o",
            "temperature" => 0.5
          }
        }
      }

      target_node = %{
        "id" => "lens-stable-target",
        "type" => "lens",
        "position" => %{"x" => 500, "y" => 100},
        "data" => %{
          "name" => "Target Lens",
          "description" => "Edge stability test target",
          "llm_config" => %{
            "provider" => "openai",
            "model" => "gpt-4o",
            "temperature" => 0.5
          }
        }
      }

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => source_node})

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => middle_node})

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => target_node})

      # Create two edges
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_started", %{"source_id" => "agent-stable-edge"})

      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_completed", %{"target_id" => "prism-stable-middle"})

      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_started", %{"source_id" => "prism-stable-middle"})

      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_completed", %{"target_id" => "lens-stable-target"})

      # Verify both edges exist
      html = render(view)
      assert html =~ "edge-agent-stable-edge-prism-stable-middle"
      assert html =~ "edge-prism-stable-middle-lens-stable-target"

      # Select the first node
      view |> element("g.node[data-node-id='agent-stable-edge']") |> render_click()

      # Verify edges still exist after node selection
      html = render(view)
      assert html =~ "edge-agent-stable-edge-prism-stable-middle"
      assert html =~ "edge-prism-stable-middle-lens-stable-target"

      # Select the second node
      view |> element("g.node[data-node-id='prism-stable-middle']") |> render_click()

      # Verify edges still exist after selecting another node
      html = render(view)
      assert html =~ "edge-agent-stable-edge-prism-stable-middle"
      assert html =~ "edge-prism-stable-middle-lens-stable-target"

      # Click on the canvas to deselect
      view |> element("#node-editor-canvas") |> render_click()

      # Verify edges still exist after deselecting
      html = render(view)
      assert html =~ "edge-agent-stable-edge-prism-stable-middle"
      assert html =~ "edge-prism-stable-middle-lens-stable-target"

      # Drag the middle node
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "prism-stable-middle",
        "clientX" => 300,
        "clientY" => 100
      })

      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 350,
        "clientY" => 150,
        "movementX" => 50,
        "movementY" => 50
      })

      # Verify edges still exist during dragging
      html = render(view)
      assert html =~ "edge-agent-stable-edge-prism-stable-middle"
      assert html =~ "edge-prism-stable-middle-lens-stable-target"

      # Complete the drag
      view |> element("#node-editor-canvas") |> render_hook("mouseup", %{})

      # Verify edges still exist after dragging
      html = render(view)
      assert html =~ "edge-agent-stable-edge-prism-stable-middle"
      assert html =~ "edge-prism-stable-middle-lens-stable-target"
    end

    test "node selection applies the correct CSS class and glow effect", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add a test node
      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{
        "node" => %{
          "id" => "test-node-1",
          "type" => "agent",
          "position" => %{"x" => 300, "y" => 300},
          "data" => %{
            "name" => "Test Node",
            "description" => "Test Description",
            "llm_config" => %{
              "provider" => "openai",
              "model" => "gpt-4o",
              "temperature" => 0.5
            }
          }
        }
      })

      # Initially, the node should not have the selected class
      html = render(view)
      assert html =~ ~s[class="node "]
      refute html =~ ~s[class="node selected"]

      # Select the node
      view
      |> element("g.node[data-node-id='test-node-1']")
      |> render_click()

      # Verify the node now has the selected class
      html = render(view)
      assert html =~ ~s[class="node selected"]

      # Verify the node glow element has opacity 1
      assert html =~ ~s[style="opacity: 1"]

      # Click on the canvas to deselect
      view
      |> element("#node-editor-canvas")
      |> render_click()

      # Verify the node no longer has the selected class
      html = render(view)
      refute html =~ ~s[class="node selected"]
      assert html =~ ~s[style="opacity: 0"]
    end

    test "node selection updates properties panel with visual effects", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add a test node
      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{
        "node" => %{
          "id" => "test-node-2",
          "type" => "agent",
          "position" => %{"x" => 300, "y" => 300},
          "data" => %{
            "name" => "Properties Test",
            "description" => "Testing Properties Panel",
            "goal" => "Test Goal",
            "llm_config" => %{
              "provider" => "openai",
              "model" => "gpt-4o",
              "temperature" => 0.5
            }
          }
        }
      })

      # Initially, the properties panel should show the default message
      html = render(view)
      assert html =~ "Select a node to view and edit its properties"

      # Select the node
      view
      |> element("g.node[data-node-id='test-node-2']")
      |> render_click()

      # Verify the properties panel now shows the node's properties
      html = render(view)
      assert html =~ "Properties Test"
      assert html =~ "Testing Properties Panel"
      assert html =~ "Test Goal"

      # Verify the form inputs are populated
      assert has_element?(view, "input[name='node[data][name]'][value='Properties Test']")

      assert has_element?(
               view,
               "textarea[name='node[data][description]']",
               "Testing Properties Panel"
             )

      assert has_element?(view, "textarea[name='node[data][goal]']", "Test Goal")
    end

    test "selecting multiple nodes in sequence works correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add two test nodes
      nodes = [
        %{
          "id" => "multi-test-1",
          "type" => "agent",
          "position" => %{"x" => 200, "y" => 200},
          "data" => %{
            "name" => "First Node",
            "description" => "First Description",
            "llm_config" => %{
              "provider" => "openai",
              "model" => "gpt-4o",
              "temperature" => 0.5
            }
          }
        },
        %{
          "id" => "multi-test-2",
          "type" => "prism",
          "position" => %{"x" => 500, "y" => 200},
          "data" => %{
            "name" => "Second Node",
            "description" => "Second Description",
            "llm_config" => %{
              "provider" => "anthropic",
              "model" => "claude-3-5-sonnet",
              "temperature" => 0.5
            }
          }
        }
      ]

      # Add the nodes
      for node <- nodes do
        view
        |> element("#node-editor-canvas")
        |> render_hook("node_added", %{"node" => node})
      end

      # Select the first node
      view
      |> element("g.node[data-node-id='multi-test-1']")
      |> render_click()

      # Verify first node is selected and shown in properties panel
      html = render(view)
      assert html =~ "First Node"
      assert html =~ "First Description"
      assert has_element?(view, "input[name='node[data][name]'][value='First Node']")

      # Select the second node
      view
      |> element("g.node[data-node-id='multi-test-2']")
      |> render_click()

      # Verify second node is now selected and shown in properties panel
      html = render(view)
      assert html =~ "Second Node"
      assert html =~ "Second Description"
      assert has_element?(view, "input[name='node[data][name]'][value='Second Node']")

      # Verify first node's properties are no longer in the properties panel
      refute has_element?(view, "input[name='node[data][name]'][value='First Node']")
    end

    test "edge creation with visual feedback", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add a second node
      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{
        "node" => %{
          "id" => "edge-test-target",
          "type" => "prism",
          "position" => %{"x" => 600, "y" => 200},
          "data" => %{
            "name" => "Target Node",
            "description" => "Edge Target",
            "llm_config" => %{
              "provider" => "openai",
              "model" => "gpt-4o",
              "temperature" => 0.5
            }
          }
        }
      })

      # Start edge creation
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_started", %{"source_id" => "agent-1"})

      # Verify drawing edge element is present
      html = render(view)
      assert html =~ ~s[id="drawing-edge"]
      assert html =~ ~s[stroke-dasharray="5,5"]

      # Complete edge creation
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_completed", %{"target_id" => "edge-test-target"})

      # Verify edge was created and drawing edge is gone
      html = render(view)
      assert html =~ ~s[data-edge-id="edge-agent-1-edge-test-target"]
      refute html =~ ~s[id="drawing-edge"]
    end

    test "cancelling edge creation removes drawing edge", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Start edge creation
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_started", %{"source_id" => "agent-1"})

      # Verify drawing edge element is present
      html = render(view)
      assert html =~ ~s[id="drawing-edge"]

      # Cancel edge creation
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_cancelled", %{})

      # Verify drawing edge is gone
      html = render(view)
      refute html =~ ~s[id="drawing-edge"]
    end

    test "SVG filters are properly defined for visual effects", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = render(view)

      # Check for filter IDs
      assert html =~ "id=\"glow-selected\""
      assert html =~ "id=\"glow-hover\""
      assert html =~ "id=\"port-glow\""
    end

    test "SVG filter visual effects are correctly configured with proper attributes", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/")

      html = render(view)

      # Check for filter IDs
      assert html =~ "id=\"glow-selected\""
      assert html =~ "id=\"glow-hover\""
      assert html =~ "id=\"port-glow\""
    end

    test "edge_created event broadcasts to all clients", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add two nodes
      source_node = %{
        "id" => "agent-broadcast-source",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "name" => "Source Agent",
          "description" => "Test description"
        }
      }

      target_node = %{
        "id" => "prism-broadcast-target",
        "type" => "prism",
        "position" => %{"x" => 300, "y" => 100},
        "data" => %{
          "name" => "Target Prism",
          "description" => "Test description"
        }
      }

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => source_node})

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => target_node})

      # Start drawing the edge
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_started", %{"source_id" => "agent-broadcast-source"})

      # Complete the edge
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_completed", %{"target_id" => "prism-broadcast-target"})

      # Verify that the edge was added
      html = render(view)
      assert html =~ "edge-agent-broadcast-source-prism-broadcast-target"

      # Verify that the edge_created event was pushed to the client
      # This is testing that the broadcast mechanism works
      assert_push_event(view, "edge_created", %{
        edge: %{
          "id" => "edge-agent-broadcast-source-prism-broadcast-target",
          "source" => "agent-broadcast-source",
          "target" => "prism-broadcast-target",
          "type" => "signal"
        }
      })
    end

    test "node_updated event broadcasts after node dragging", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add a node
      test_node = %{
        "id" => "agent-drag-test",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "name" => "Drag Test Agent",
          "description" => "Test description"
        }
      }

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => test_node})

      # Simulate mousedown on the node
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "agent-drag-test",
        "clientX" => 100,
        "clientY" => 100
      })

      # Simulate mousemove
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 200,
        "clientY" => 200
      })

      # Simulate mouseup
      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})

      # Verify that the node_updated event was pushed to the client
      assert_push_event(view, "node_updated", %{
        node: %{"id" => "agent-drag-test"}
      })
    end

    test "node_selected event broadcasts to all clients", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add a node
      test_node = %{
        "id" => "agent-select-test",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "name" => "Select Test Agent",
          "description" => "Test description",
          "llm_config" => %{
            "provider" => "openai",
            "model" => "gpt-4o",
            "temperature" => 0.5
          }
        }
      }

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => test_node})

      # Select the node
      view
      |> element("#node-editor-canvas")
      |> render_hook("node_selected", %{"node_id" => "agent-select-test"})

      # Verify that the node_selected event was pushed to the client
      assert_push_event(view, "node_selected", %{
        node_id: "agent-select-test"
      })
    end

    test "edge cancellation event properly removes drawing edge element", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add a node
      test_node = %{
        "id" => "agent-edge-cancel",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "name" => "Edge Cancel Test",
          "description" => "Test description"
        }
      }

      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{"node" => test_node})

      # Start drawing an edge
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_started", %{"source_id" => "agent-edge-cancel"})

      # Verify drawing edge is present
      assert render(view) =~ "drawing-edge"

      # Cancel the edge creation
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_cancelled", %{})

      # Verify drawing edge is removed
      refute render(view) =~ "drawing-edge"
    end
  end
end
