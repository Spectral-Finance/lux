import time
class SwarmMemory:
    def __init__(self): self.ledger = {}
    def write_agent_state(self, agent_id, ctx, ttl=3600):
        self.ledger[agent_id] = {"context": ctx, "expiry": time.time() + ttl}
    def read_agent_state(self, agent_id):
        state = self.ledger.get(agent_id)
        if not state or time.time() > state['expiry']:
            if state: del self.ledger[agent_id]
            return None
        return state['context']
