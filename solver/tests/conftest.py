from pathlib import Path

import pytest

FIXTURES = Path(__file__).resolve().parents[2] / "fixtures"

@pytest.fixture(scope="session")
def fixtures_dir() -> Path:
    assert FIXTURES.is_dir(), f"fixtures dir missing at {FIXTURES}"
    return FIXTURES
