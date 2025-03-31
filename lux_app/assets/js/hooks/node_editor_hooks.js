const NodeEditorHooks = {
  DraggableNode: {
    mounted() {
      this.el.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('node-type', this.el.dataset.type);
      });
    }
  },

  NodeDraggable: {
    mounted() {
      // Add hover effects
      this.setupHoverEffects();
      
      // Handle node selection
      this.handleNodeSelection();
      
      this.el.addEventListener('mousedown', (e) => {
        // Only handle left mouse button
        if (e.button !== 0) return;
        
        // Get the node ID from the data attribute
        const nodeId = this.el.dataset.nodeId;
        
        // Get SVG element for coordinate calculations
        const svg = document.querySelector('#node-editor-canvas svg');
        const svgRect = svg.getBoundingClientRect();
        
        // Calculate mouse position relative to SVG
        const mouseX = e.clientX - svgRect.left;
        const mouseY = e.clientY - svgRect.top;
        
        console.log(`NodeDraggable: mousedown on node ${nodeId} at position (${mouseX}, ${mouseY})`);
        
        // Push event to the canvas hook
        this.pushEventTo('#node-editor-canvas', 'mousedown', {
          node_id: nodeId,
          clientX: mouseX,
          clientY: mouseY
        });
        
        e.preventDefault();
      });
    },
    
    handleNodeSelection() {
      // Listen for node selection events from the server
      this.handleEvent("node_selected", ({ node_id }) => {
        // If this is the selected node, apply the glow effect
        if (this.el.dataset.nodeId === node_id) {
          const nodeBody = this.el.querySelector('.node-body');
          nodeBody.setAttribute('filter', 'url(#glow-selected)');
        } else {
          // Remove glow effect from other nodes
          const nodeBody = this.el.querySelector('.node-body');
          nodeBody.removeAttribute('filter');
        }
      });
      
      // Also listen for canvas clicks to handle deselection
      this.handleEvent("canvas_clicked", () => {
        const nodeBody = this.el.querySelector('.node-body');
        nodeBody.removeAttribute('filter');
      });
    },
    
    setupHoverEffects() {
      // Create a glow effect for hover state
      const nodeBody = this.el.querySelector('.node-body');
      const nodeGlow = this.el.querySelector('.node-glow');
      
      // Add hover effect to the node
      this.el.addEventListener('mouseenter', () => {
        // Only apply hover effect if the node is not selected
        if (!this.el.classList.contains('selected')) {
          nodeBody.setAttribute('filter', 'url(#glow-hover)');
        }
      });
      
      this.el.addEventListener('mouseleave', () => {
        // Remove hover effect
        if (!this.el.classList.contains('selected')) {
          nodeBody.removeAttribute('filter');
        } else {
          // If selected, make sure the selected glow is applied
          nodeBody.setAttribute('filter', 'url(#glow-selected)');
        }
      });
    }
  },

  NodeCanvas: {
    mounted() {
      this.isDragging = false;
      this.draggedNode = null;
      this.isDrawingEdge = false;
      this.startPort = null;
      this.mousePosition = { x: 0, y: 0 };
      this.dragStartPosition = { x: 0, y: 0 };
      this.selectedNodeId = null;
      this.edgeUpdateScheduled = false;

      // Get SVG element for coordinate calculations
      this.svg = this.el.querySelector('svg');

      // Setup event listeners
      this.el.addEventListener('dragover', this.handleDragOver.bind(this));
      this.el.addEventListener('drop', this.handleDrop.bind(this));
      this.el.addEventListener('mousemove', this.handleMouseMove.bind(this));

      // Setup node dragging event listeners
      this.el.addEventListener('mousedown', this.handleNodeMouseDown.bind(this));
      document.addEventListener('mousemove', this.handleNodeDrag.bind(this));
      document.addEventListener('mouseup', this.handleNodeMouseUp.bind(this));
      document.addEventListener('keydown', this.handleKeyDown.bind(this));
      
      // Setup port event listeners
      this.setupPortListeners();
      
      // Setup edge path calculations - run after a short delay to ensure DOM is ready
      setTimeout(() => this.updateEdgePaths(), 100);
      
      // Setup MutationObserver to watch for DOM changes that might affect edges
      this.setupMutationObserver();
      
      // Listen for node selection events
      this.handleEvent("node_selected", ({ node_id }) => {
        console.log("Node selected:", node_id);
        this.selectedNodeId = node_id;
        
        // Update all nodes to reflect the selection state
        document.querySelectorAll('.node').forEach(node => {
          if (node.dataset.nodeId === node_id) {
            node.classList.add('selected');
          } else {
            node.classList.remove('selected');
          }
        });
        
        // Update edge paths after selection changes
        this.scheduleEdgePathUpdate();
      });
      
      // Listen for canvas click events (deselection)
      this.handleEvent("canvas_clicked", () => {
        console.log("Canvas clicked, deselecting node");
        this.selectedNodeId = null;
        
        // Remove selected class from all nodes
        document.querySelectorAll('.node').forEach(node => {
          node.classList.remove('selected');
        });
        
        // Update edge paths after deselection
        this.scheduleEdgePathUpdate();
      });
      
      // Listen for edge creation events
      this.handleEvent("edge_completed", () => {
        console.log("Edge completed event received");
        // Update edge paths after a new edge is created
        this.scheduleEdgePathUpdate(50);
      });
      
      // Listen for edge created events (broadcast from server)
      this.handleEvent("edge_created", ({ edge }) => {
        console.log("Edge created event received:", edge);
        
        // Check if the edge path element already exists
        const edgeId = edge.id;
        let edgePath = this.el.querySelector(`path.edge-path[data-edge-id="${edgeId}"]`);
        
        if (!edgePath) {
          console.log("Edge path element not found, may need to wait for DOM update");
        }
        
        // Force edge paths update to ensure the new edge is rendered
        this.scheduleEdgePathUpdate(100);
        
        // Highlight the new edge briefly to provide visual feedback
        setTimeout(() => {
          edgePath = this.el.querySelector(`path.edge-path[data-edge-id="${edgeId}"]`);
          if (edgePath) {
            edgePath.setAttribute('stroke', '#fff');
            edgePath.setAttribute('stroke-width', '3');
            
            setTimeout(() => {
              edgePath.setAttribute('stroke', '#666');
              edgePath.setAttribute('stroke-width', '2');
            }, 500);
          }
        }, 150);
      });
      
      // Listen for node added events
      this.handleEvent("node_added", () => {
        console.log("Node added event received");
        this.scheduleEdgePathUpdate(100);
      });
      
      // Listen for node removed events
      this.handleEvent("node_removed", () => {
        console.log("Node removed event received");
        this.scheduleEdgePathUpdate(100);
      });
      
      // Listen for node updated events
      this.handleEvent("node_updated", () => {
        console.log("Node updated event received");
        this.scheduleEdgePathUpdate(100);
      });

      this.handleEvent("all_exported", (data) => {
        // Create a Blob containing the JSON data
        const jsonContent = JSON.stringify(data, null, 2);
        const blob = new Blob([jsonContent], { type: 'application/json' });
        
        // Create a temporary download link
        const downloadLink = document.createElement('a');
        downloadLink.href = URL.createObjectURL(blob);
        downloadLink.download = 'agents.json';
        
        // Append link, trigger download, and cleanup
        document.body.appendChild(downloadLink);
        downloadLink.click();
        document.body.removeChild(downloadLink);
        URL.revokeObjectURL(downloadLink.href);
        console.log("Export JSON event received", data);
      });
    },

    destroyed() {
      // Cleanup event listeners and observers
      if (this.mutationObserver) {
        this.mutationObserver.disconnect();
      }
    },
    
    setupMutationObserver() {
      // Create a MutationObserver to watch for changes to the SVG
      this.mutationObserver = new MutationObserver((mutations) => {
        let shouldUpdateEdges = false;
        
        // Check if any mutations affect nodes or edges
        for (const mutation of mutations) {
          if (mutation.type === 'childList') {
            // Check if added or removed nodes affect our edges
            const addedNodes = Array.from(mutation.addedNodes);
            const removedNodes = Array.from(mutation.removedNodes);
            
            const relevantNodeAdded = addedNodes.some(node => 
              node.classList && (node.classList.contains('node') || node.classList.contains('edge'))
            );
            
            const relevantNodeRemoved = removedNodes.some(node => 
              node.classList && (node.classList.contains('node') || node.classList.contains('edge'))
            );
            
            if (relevantNodeAdded || relevantNodeRemoved) {
              shouldUpdateEdges = true;
              break;
            }
          } else if (mutation.type === 'attributes') {
            // Check if attribute changes affect node positions
            if (mutation.attributeName === 'transform' && 
                mutation.target.classList && 
                mutation.target.classList.contains('node')) {
              shouldUpdateEdges = true;
              break;
            }
          }
        }
        
        if (shouldUpdateEdges) {
          console.log("DOM mutation detected that affects edges, updating edge paths");
          this.scheduleEdgePathUpdate(50);
        }
      });
      
      // Start observing the SVG element
      this.mutationObserver.observe(this.svg, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['transform', 'data-node-id', 'data-edge-id']
      });
    },
    
    scheduleEdgePathUpdate(delay = 0) {
      // Prevent multiple updates in quick succession
      if (this.edgeUpdateScheduled) return;
      
      this.edgeUpdateScheduled = true;
      
      setTimeout(() => {
        this.updateEdgePaths();
        this.edgeUpdateScheduled = false;
      }, delay);
    },

    handleDragOver(e) {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
    },

    handleDrop(e) {
      e.preventDefault();
      const nodeType = e.dataTransfer.getData('node-type');
      if (!nodeType) return;

      const svgRect = this.svg.getBoundingClientRect();
      const x = e.clientX - svgRect.left;
      const y = e.clientY - svgRect.top;

      // Generate a unique ID for the new node
      const nodeId = `${nodeType}-${Date.now()}`;

      // Push the new node to the server
      this.pushEvent('node_added', {
        node: {
          id: nodeId,
          type: nodeType,
          position: { x, y },
          data: this.getInitialNodeData(nodeType)
        }
      });
      
      // Update edge paths after adding a new node
      this.scheduleEdgePathUpdate(100);
    },

    handleMouseMove(e) {
      const svgRect = this.svg.getBoundingClientRect();
      this.mousePosition = {
        x: e.clientX - svgRect.left,
        y: e.clientY - svgRect.top
      };

      if (this.isDrawingEdge) {
        this.updateDrawingEdge();
      }
    },

    handleNodeMouseDown(e) {
      // If the click is on a port, don't initiate node dragging
      if (e.target.closest('.port')) return;
      
      const node = e.target.closest('.node');
      if (!node || e.button !== 0) return;

      this.isDragging = true;
      this.draggedNode = node;
      
      const svgRect = this.svg.getBoundingClientRect();
      this.dragStartPosition = {
        x: e.clientX - svgRect.left,
        y: e.clientY - svgRect.top
      };

      // Notify server about drag start
      this.pushEvent('mousedown', {
        button: 0,
        clientX: this.dragStartPosition.x,
        clientY: this.dragStartPosition.y,
        node_id: node.dataset.nodeId
      });

      e.preventDefault();
    },

    handleNodeDrag(e) {
      if (!this.isDragging || !this.draggedNode) return;

      const svgRect = this.svg.getBoundingClientRect();
      const currentX = e.clientX - svgRect.left;
      const currentY = e.clientY - svgRect.top;

      // Calculate movement
      const movementX = currentX - this.dragStartPosition.x;
      const movementY = currentY - this.dragStartPosition.y;

      console.log(`NodeCanvas: dragging node to position (${currentX}, ${currentY})`);

      // Notify server about movement
      this.pushEvent('mousemove', {
        clientX: currentX,
        clientY: currentY,
        movementX: movementX,
        movementY: movementY
      });

      // Update edge paths during drag - call immediately after position update
      this.scheduleEdgePathUpdate(0);

      e.preventDefault();
    },

    handleNodeMouseUp(e) {
      if (!this.isDragging) return;

      const nodeId = this.draggedNode ? this.draggedNode.dataset.nodeId : 'unknown';
      console.log(`NodeCanvas: finished dragging node ${nodeId}`);

      this.isDragging = false;
      this.draggedNode = null;
      this.dragStartPosition = { x: 0, y: 0 };

      // Notify server about drag end
      this.pushEvent('mouseup', {});

      // Update edge paths after drag is complete - ensure it runs after the server updates
      this.scheduleEdgePathUpdate(50);

      e.preventDefault();
    },

    handleKeyDown(e) {
      if (e.key === 'Escape' && this.isDragging) {
        this.pushEvent('keydown', { key: 'Escape' });
        this.isDragging = false;
        this.draggedNode = null;
        this.dragStartPosition = { x: 0, y: 0 };
        
        // Update edge paths after cancelling drag
        this.scheduleEdgePathUpdate(50);
      } else if (e.key === 'Backspace') {
        this.pushEvent('node_removed', {
          id: this.selectedNodeId
        });
      }
    },

    setupPortListeners() {
      // Handle port interactions for edge creation
      this.el.addEventListener('mousedown', (e) => {
        const port = e.target.closest('.port');
        if (!port) return;

        const node = port.closest('.node');
        if (!node) return;

        // Stop event propagation to prevent node dragging
        e.stopPropagation();
        
        console.log('Port mousedown detected:', {
          nodeId: node.dataset.nodeId,
          isOutput: port.classList.contains('output'),
          isInput: port.classList.contains('input'),
          portElement: port,
          nodeElement: node
        });

        // Get the port's position in SVG coordinates
        const nodeTransform = node.getAttribute('transform');
        const nodePos = this.parseTransform(nodeTransform);
        
        // Calculate port position based on its cx/cy attributes and node position
        const portCx = parseFloat(port.getAttribute('cx'));
        const portCy = parseFloat(port.getAttribute('cy'));
        const portX = nodePos.x + portCx;
        const portY = nodePos.y + portCy;
        
        console.log('Port position:', { portX, portY });

        this.isDrawingEdge = true;
        this.startPort = {
          nodeId: node.dataset.nodeId,
          isOutput: port.classList.contains('output'),
          x: portX,
          y: portY
        };

        // Notify server that we started drawing an edge
        this.pushEvent('edge_started', {
          source_id: this.startPort.nodeId
        });
        
        console.log('Edge drawing started:', this.isDrawingEdge, this.startPort);
      });

      this.el.addEventListener('mouseup', (e) => {
        console.log('Mouseup detected, isDrawingEdge:', this.isDrawingEdge);
        if (!this.isDrawingEdge) return;

        const port = e.target.closest('.port');
        console.log('Target port:', port);
        
        if (port) {
          // Stop event propagation to prevent node dragging
          e.stopPropagation();
          
          const node = port.closest('.node');
          console.log('Target node:', node);
          
          if (node) {
            const endNodeId = node.dataset.nodeId;
            const isInput = port.classList.contains('input');

            console.log('Edge completion candidate:', {
              sourceId: this.startPort.nodeId,
              targetId: endNodeId,
              sourceIsOutput: this.startPort.isOutput,
              targetIsInput: isInput
            });

            // Only connect if we're going from output to input
            if (this.startPort.isOutput && isInput) {
              console.log('Edge completed successfully');
              this.pushEvent('edge_completed', {
                target_id: endNodeId
              });
              
              // Force edge paths update after a short delay to ensure server has processed the edge
              this.scheduleEdgePathUpdate(100);
            } else {
              console.log('Edge not completed: port type mismatch');
            }
          }
        }

        this.isDrawingEdge = false;
        this.startPort = null;
        this.pushEvent('edge_cancelled', {});
        console.log('Edge drawing cancelled/completed');
        
        // Update edge paths after edge creation is cancelled
        this.scheduleEdgePathUpdate(50);
      });
      
      // Add hover effects for ports
      this.setupPortHoverEffects();
    },
    
    setupPortHoverEffects() {
      // Use event delegation for port hover effects
      this.el.addEventListener('mouseover', (e) => {
        const port = e.target.closest('.port');
        if (port) {
          // Apply glow effect to port
          port.setAttribute('filter', 'url(#port-glow)');
          port.setAttribute('r', '6'); // Slightly increase size
        }
      });
      
      this.el.addEventListener('mouseout', (e) => {
        const port = e.target.closest('.port');
        if (port) {
          // Remove glow effect
          port.removeAttribute('filter');
          port.setAttribute('r', '5'); // Reset to original size
        }
      });
    },

    updateDrawingEdge() {
      if (!this.isDrawingEdge || !this.startPort) return;

      const drawingEdge = this.el.querySelector('#drawing-edge');
      if (!drawingEdge) {
        console.error('Drawing edge element not found');
        return;
      }

      // Use the exact port position instead of calculating from the node
      const startX = this.startPort.x;
      const startY = this.startPort.y;
      
      // Create a path from the port to the current mouse position
      const path = `M ${startX} ${startY} 
                    C ${startX + 50} ${startY},
                      ${this.mousePosition.x - 50} ${this.mousePosition.y},
                      ${this.mousePosition.x} ${this.mousePosition.y}`;

      drawingEdge.setAttribute('d', path);
      console.log('Drawing edge updated');
    },

    updateEdgePaths() {
      const edges = this.el.querySelectorAll('.edge-path');
      
      console.log(`Updating ${edges.length} edge paths`);
      
      if (edges.length === 0) {
        console.log('No edges to update');
        return;
      }
      
      let updatedCount = 0;
      let errorCount = 0;
      
      edges.forEach(edge => {
        try {
          const sourceId = edge.dataset.source;
          const targetId = edge.dataset.target;
          
          if (!sourceId || !targetId) {
            console.warn('Edge missing source or target ID', edge);
            errorCount++;
            return;
          }
          
          const sourceNode = this.el.querySelector(`[data-node-id="${sourceId}"]`);
          const targetNode = this.el.querySelector(`[data-node-id="${targetId}"]`);
          
          if (!sourceNode || !targetNode) {
            console.warn(`Could not find nodes for edge: ${sourceId} -> ${targetId}`);
            errorCount++;
            return;
          }
          
          const path = this.calculateEdgePath(
            { nodeId: sourceId },
            { nodeId: targetId },
            true
          );
          
          edge.setAttribute('d', path);
          updatedCount++;
        } catch (error) {
          console.error('Error updating edge path:', error);
          errorCount++;
        }
      });
      
      console.log(`Edge path update complete: ${updatedCount} updated, ${errorCount} errors`);
      
      // If we had errors but some edges were updated, schedule another update
      if (errorCount > 0 && updatedCount > 0) {
        console.log('Some edges failed to update, scheduling retry');
        setTimeout(() => this.updateEdgePaths(), 200);
      }
    },

    calculateEdgePath(start, end, isOutput) {
      try {
        // Calculate port positions based on node positions
        const sourceNode = this.el.querySelector(`[data-node-id="${start.nodeId || start.x}"]`);
        const targetNode = this.el.querySelector(`[data-node-id="${end.nodeId || end.x}"]`);
        
        let startX, startY, endX, endY;
        
        if (sourceNode && targetNode) {
          // For existing edges between nodes
          const sourcePos = this.parseTransform(sourceNode.getAttribute('transform'));
          const targetPos = this.parseTransform(targetNode.getAttribute('transform'));
          
          // Add the port offset to the node position
          startX = sourcePos.x + 200; // Output port is on the right side
          startY = sourcePos.y + 50;  // Ports are vertically centered
          endX = targetPos.x;         // Input port is on the left side
          endY = targetPos.y + 50;    // Ports are vertically centered
        } else {
          // For drawing edges or other cases
          startX = start.x !== undefined ? start.x : start.x + (isOutput ? 200 : 0);
          startY = start.y !== undefined ? start.y : start.y + 50;
          endX = end.x !== undefined ? end.x : end.x + (isOutput ? 0 : 200);
          endY = end.y !== undefined ? end.y : end.y + 50;
        }
  
        // Calculate control points for the curve
        const dx = Math.abs(endX - startX);
        const controlOffset = Math.min(dx * 0.5, 150);
  
        // Create a smooth curve using cubic bezier
        return `M ${startX} ${startY} 
                C ${startX + controlOffset} ${startY},
                  ${endX - controlOffset} ${endY},
                  ${endX} ${endY}`;
      } catch (error) {
        console.error('Error calculating edge path:', error);
        // Return a default path in case of error
        return 'M 0 0 L 0 0';
      }
    },

    parseTransform(transform) {
      if (!transform) return { x: 0, y: 0 };
      const match = transform.match(/translate\(([^,]+),([^)]+)\)/);
      if (!match) return { x: 0, y: 0 };
      return {
        x: parseFloat(match[1]),
        y: parseFloat(match[2])
      };
    },

    getInitialNodeData(type) {
      switch (type) {
        case 'agent':
          return {
            label: 'New Agent',
            description: 'Agent description',
            goal: 'Agent goal',
            components: []
          };
        case 'prism':
          return {
            label: 'New Prism',
            description: 'Prism description',
            input_schema: null,
            output_schema: null
          };
        case 'lens':
          return {
            label: 'New Lens',
            description: 'Lens description',
            url: '',
            method: 'GET',
            schema: null
          };
        case 'beam':
          return {
            label: 'New Beam',
            description: 'Beam description',
            input_schema: null,
            output_schema: null
          };
        default:
          return { label: 'New Node' };
      }
    }
  }
};

export default NodeEditorHooks; 