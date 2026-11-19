import time
from lux import SwarmMemoryPrism


def test_swarm_memory_prism_put_get_and_ttl_eviction():
    prism = SwarmMemoryPrism()
    assert prism.handler({"action": "put", "key": "agent_1", "value": {"task": "scan"}, "ttl_seconds": 60})["status"] == "ok"
    assert prism.handler({"action": "get", "key": "agent_1"})["value"] == {"task": "scan"}

    prism.handler({"action": "put", "key": "ephemeral", "value": 42, "ttl_seconds": 0.01})
    time.sleep(0.03)
    assert prism.handler({"action": "get", "key": "ephemeral"})["value"] is None