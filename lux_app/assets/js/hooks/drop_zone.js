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
      const x = e.clientX - svgRect.left;
      const y = e.clientY - svgRect.top;

      const reader = new FileReader();
      reader.onload = (event) => {
        const content = JSON.parse(event.target.result);
        // TODO: validate type properly (agent, lens, prism, beam)
        if (typeof content === 'object' && content.type) {
          this.pushEvent('node_added', {
            node: {
              ...content,
              id: `${content.type}-${Date.now()}`,
              position: { x, y }
            }
          });
        } else {
          console.error('Invalid JSON file:', content);
          this.pushEvent('node_added_error', { message: 'Invalid JSON file' });
        }
      };
      reader.readAsText(jsonFile);
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