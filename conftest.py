"""Root pytest configuration for the Lux repo.

Ensures the repository root is importable so that top-level modules such as
``shopify_integration`` can be imported by the test suite regardless of how
pytest is invoked (``pytest``, ``python -m pytest``, etc.).
"""

import os
import sys

_ROOT = os.path.dirname(os.path.abspath(__file__))
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)