"""
from abc import ABC, abstractmethod
from typing import Any, Dict, Optional, Tuple, Type, Union
from .signals import Signal, SignalSchema

class SignalHandler(ABC):
    """Base class for handling signals in a Lux agent."""
    
    def __init__(self, agent_id: str):
        self.agent_id = agent_id
        self._signal_handlers = {}
        
    def register_handler(self, schema: Type[SignalSchema], handler_method: str) -> None:
        """Register a method to handle signals of a specific schema."""
        if not hasattr(self, handler_method):
            raise ValueError(f"Handler method {handler_method} not found")
        self._signal_handlers[schema] = getattr(self, handler_method)
        
    def handle_signal(self, signal: Signal) -> Tuple[bool, Optional[Signal]]:
        """Handle an incoming signal.
        
        Returns:
            Tuple[bool, Optional[Signal]]: (success, response_signal)
        """
        if not signal.schema_id:
            return False, None
            
        handler = self._signal_handlers.get(signal.schema_id)
        if not handler:
            return False, None
            
        try:
            response = handler(signal)
            if isinstance(response, Signal):
                return True, response
            elif isinstance(response, tuple) and len(response) == 2:
                success, data = response
                if success and isinstance(data, dict):
                    return True, Signal(
                        schema_id=signal.schema_id,
                        payload=data,
                        recipient=signal.sender,
                        sender=self.agent_id
                    )
            return True, None
        except Exception as e:
            # Log error and return failure
            print(f"Error handling signal: {str(e)}")
            return False, None

class TaskHandler(SignalHandler):
    """Handler for task-related signals."""
    
    def __init__(self, agent_id: str):
        super().__init__(agent_id)
        from .signals import TaskSchema
        self.register_handler(TaskSchema, "handle_task")
    
    @abstractmethod
    def handle_task(self, signal: Signal) -> Union[Signal, Tuple[bool, Dict[str, Any]]]:
        """Handle a task signal.
        
        Args:
            signal: The incoming task signal
            
        Returns:
            Either a response Signal or a tuple (success, response_data)
        """
        pass

class ObjectiveHandler(SignalHandler):
    """Handler for objective-related signals."""
    
    def __init__(self, agent_id: str):
        super().__init__(agent_id)
        from .signals import ObjectiveSchema
        self.register_handler(ObjectiveSchema, "handle_objective")
    
    @abstractmethod
    def handle_objective(self, signal: Signal) -> Union[Signal, Tuple[bool, Dict[str, Any]]]:
        """Handle an objective signal.
        
        Args:
            signal: The incoming objective signal
            
        Returns:
            Either a response Signal or a tuple (success, response_data)
        """
        pass

class LuxAgent:
    """Base class for creating Lux-compatible agents in Python."""
    
    def __init__(self, agent_id: str, name: str, description: str = "", goal: str = ""):
        self.agent_id = agent_id
        self.name = name
        self.description = description
        self.goal = goal
        self._signal_handlers: list[SignalHandler] = []
        
    def add_handler(self, handler: SignalHandler) -> None:
        """Add a signal handler to the agent."""
        self._signal_handlers.append(handler)
        
    def handle_signal(self, signal: Signal) -> Optional[Signal]:
        """Handle an incoming signal using registered handlers."""
        for handler in self._signal_handlers:
            success, response = handler.handle_signal(signal)
            if success:
                return response
        return None

# Example usage:
class MyTaskHandler(TaskHandler):
    def handle_task(self, signal: Signal) -> Tuple[bool, Dict[str, Any]]:
        # Extract task details
        task = signal.payload
        task_type = task.get("type")
        
        if task_type == "assignment":
            # Handle new task assignment
            return True, {
                "type": "status_update",
                "task_id": task["task_id"],
                "title": task["title"],
                "status": "in_progress",
                "progress": 0
            }
        elif task_type == "status_update":
            # Handle status update request
            return True, {
                "type": "status_update",
                "task_id": task["task_id"],
                "title": task["title"],
                "status": "completed",
                "progress": 100
            }
        
        return False, {"error": "Unsupported task type"}

# Example agent creation:
def create_example_agent():
    agent = LuxAgent(
        agent_id="python-agent-1",
        name="Python Example Agent",
        description="An example agent implementing the Lux signal protocol",
        goal="Handle tasks and provide status updates"
    )
    
    # Add handlers
    agent.add_handler(MyTaskHandler(agent.agent_id))
    
    return agent
""" 