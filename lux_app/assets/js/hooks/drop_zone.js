import { NODE_WIDTH, NODE_HEIGHT } from '../consts';

const createComponentNode = (type, data, index) => {
  if (typeof data === 'string') {
    const name = data.split('.').pop();
    return {
      type,
      id: `${type}-${index}`,
      data: {
        name,
        module: data,
      }
    }
  } else if (typeof data === 'object' && data.name) {
    return {
      type,
      id: `${type}-${index}`,
      data
    }
  }

  throw new Error('Cannot create component node from given data');
};

const JsonDropZone = {
  mounted() {
    // Counter to track drag enter/leave events
    let dragCounter = 0;

    // Handle dragenter on window
    window.addEventListener('dragenter', (e) => {
      e.preventDefault();
      dragCounter++;
      
      // Check if the dragged item is a JSON file
      if (e.dataTransfer.types.includes('Files')) {
        const items = Array.from(e.dataTransfer.items);
        const hasJsonFile = items.some(item => 
          item.type === 'application/json' || 
          (item.type === '' && item.kind === 'file') // For when file type is not immediately available
        );
        
        if (hasJsonFile) {
          this.el.setAttribute('data-dragging', 'true');
        }
      }
    });

    // Handle dragleave on window
    window.addEventListener('dragleave', (e) => {
      e.preventDefault();
      dragCounter--;
      
      // Only hide if we've left all drag events
      if (dragCounter === 0) {
        this.el.setAttribute('data-dragging', 'false');
      }
    });

    // Handle drop on the drop zone
    this.el.addEventListener('drop', (e) => {
      e.preventDefault();
      e.stopPropagation();
      dragCounter = 0;
      this.el.setAttribute('data-dragging', 'false');

      const svg = document.querySelector('#node-editor-canvas svg');
      const svgRect = svg.getBoundingClientRect();
      const x = e.clientX - svgRect.left - NODE_WIDTH / 2;
      const y = e.clientY - svgRect.top - NODE_HEIGHT / 2;

      const reader = new FileReader();
      reader.onload = (event) => {
        try {
          const parsedData = JSON.parse(event.target.result);
          
          const beams = parsedData.beams.map((data, index) => createComponentNode('beam', data, index));
          const lenses = parsedData.lenses.map((data, index) => createComponentNode('lens', data, index));
          const prisms = parsedData.prisms.map((data, index) => createComponentNode('prism', data, index));
          const agent = {
            type: 'agent',
            id: `agent-${Date.now()}`,
            data: {
              ...parsedData,
              beams: beams.map(beam => beam.id),
              lenses: lenses.map(lens => lens.id),
              prisms: prisms.map(prism => prism.id)
            }
          };
          
          const nodes = [agent, ...beams, ...lenses, ...prisms].map((node, index) => ({
            ...node,
            position: {
              x: x + NODE_WIDTH / 3 * index,
              y: y + NODE_HEIGHT / 3 * index
            }
          }));
          
          nodes.forEach(node => {
            this.pushEvent('node_added', { node });
          });
        } catch (error) {
          console.error('Invalid JSON file:', error);
          this.pushEvent('node_added_error', { message: 'Invalid JSON file' });
        }
      };
      reader.readAsText(e.dataTransfer.files[0]);
    });

    // Handle dragover on the drop zone
    this.el.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.stopPropagation();
    });

    // Reset counter when drag ends
    window.addEventListener('dragend', () => {
      dragCounter = 0;
      this.el.setAttribute('data-dragging', 'false');
    });

    // Reset counter when drop happens anywhere
    window.addEventListener('drop', (e) => {
      e.preventDefault();
      dragCounter = 0;
      this.el.setAttribute('data-dragging', 'false');
    });
  }
};

export default JsonDropZone;