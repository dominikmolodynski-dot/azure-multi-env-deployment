import pytest
from azure.core.exceptions import (
    HttpResponseError,
    ResourceExistsError,
    ResourceNotFoundError,
)

from app import create_app
from store import InMemoryVisitStore, TableVisitStore


@pytest.fixture
def client():
    return create_app(InMemoryVisitStore()).test_client()


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_index_counts_each_visit(client):
    assert b"Hello World!" in client.get("/").data
    client.get("/")
    assert client.get("/api/visits").get_json()["visits"] == 2


def test_api_does_not_count_as_visit(client):
    client.get("/api/visits")
    assert client.get("/api/visits").get_json()["visits"] == 0


def test_environment_name_is_shown(monkeypatch):
    monkeypatch.setenv("APP_ENVIRONMENT", "staging")
    client = create_app(InMemoryVisitStore()).test_client()
    assert b"staging" in client.get("/").data
    assert client.get("/api/visits").get_json()["environment"] == "staging"


class FakeEntity(dict):
    def __init__(self, count, etag):
        super().__init__(count=count)
        self.metadata = {"etag": etag}


class FakeTable:
    """Minimal stand-in for azure.data.tables.TableClient with ETag checks."""

    def __init__(self, conflicts=0):
        self.count = None
        self.version = 0
        self.conflicts = conflicts  # number of updates to reject with HTTP 412

    def get_entity(self, partition_key, row_key):
        if self.count is None:
            raise ResourceNotFoundError("not found")
        return FakeEntity(self.count, self.version)

    def create_entity(self, entity):
        if self.count is not None:
            raise ResourceExistsError("exists")
        self.count = entity["count"]

    def update_entity(self, entity, mode, etag, match_condition):
        if self.conflicts > 0 or etag != self.version:
            self.conflicts -= 1
            error = HttpResponseError("precondition failed")
            error.status_code = 412
            raise error
        self.count = entity["count"]
        self.version += 1


def test_table_store_creates_then_increments():
    store = TableVisitStore(FakeTable())
    assert store.get() == 0
    assert store.increment() == 1
    assert store.increment() == 2
    assert store.get() == 2


def test_table_store_retries_on_concurrent_update():
    table = FakeTable(conflicts=3)
    table.count = 5
    assert TableVisitStore(table).increment() == 6


def test_table_store_gives_up_after_too_many_conflicts():
    table = FakeTable(conflicts=1000)
    table.count = 5
    with pytest.raises(RuntimeError):
        TableVisitStore(table).increment()
