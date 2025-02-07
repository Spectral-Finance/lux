"""
Simple implementation of Erlang atoms for Python-Elixir interop.
"""

class Atom:
    """Represents an Erlang atom in Python."""
    
    def __init__(self, name):
        """Create a new atom with the given name.
        
        Args:
            name (str or bytes): The atom name. If bytes are provided, they're used as-is.
                               If str is provided, it's encoded to bytes using utf-8.
        """
        if isinstance(name, str):
            self.name = name.encode('utf-8')
        elif isinstance(name, bytes):
            self.name = name
        else:
            raise TypeError(f"Atom name must be str or bytes, not {type(name)}")

    def __repr__(self):
        return f"Atom({self.name!r})"
    
    def __str__(self):
        return self.name.decode('utf-8')
    
    def __eq__(self, other):
        if not isinstance(other, Atom):
            return False
        return self.name == other.name
    
    def __hash__(self):
        return hash(self.name) 