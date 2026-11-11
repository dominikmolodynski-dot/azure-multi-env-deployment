"""Visit counter storage backends."""

import os
import threading

PARTITION_KEY = "counter"
ROW_KEY = "visits"
MAX_RETRIES = 10


class InMemoryVisitStore:
    """Counter kept in process memory. For local development and tests."""

    def __init__(self):
        self._count = 0
        self._lock = threading.Lock()

    def increment(self):
        with self._lock:
            self._count += 1
            return self._count

    def get(self):
        return self._count


class TableVisitStore:
    """Counter kept in a single Azure Table Storage entity.

    Several app instances may increment at once, so updates use optimistic
    concurrency: write only if the entity's ETag is unchanged, else retry.
    """

    def __init__(self, table_client):
        self._table = table_client

    def get(self):
        from azure.core.exceptions import ResourceNotFoundError

        try:
            return int(self._table.get_entity(PARTITION_KEY, ROW_KEY)["count"])
        except ResourceNotFoundError:
            return 0

    def increment(self):
        from azure.core import MatchConditions
        from azure.core.exceptions import (
            HttpResponseError,
            ResourceExistsError,
            ResourceNotFoundError,
        )
        from azure.data.tables import UpdateMode

        for _ in range(MAX_RETRIES):
            try:
                entity = self._table.get_entity(PARTITION_KEY, ROW_KEY)
            except ResourceNotFoundError:
                try:
                    self._table.create_entity(
                        {"PartitionKey": PARTITION_KEY, "RowKey": ROW_KEY, "count": 1}
                    )
                    return 1
                except ResourceExistsError:
                    continue  # another instance created it first

            new_count = int(entity["count"]) + 1
            try:
                self._table.update_entity(
                    {"PartitionKey": PARTITION_KEY, "RowKey": ROW_KEY, "count": new_count},
                    mode=UpdateMode.REPLACE,
                    etag=entity.metadata["etag"],
                    match_condition=MatchConditions.IfNotModified,
                )
                return new_count
            except HttpResponseError as error:
                if error.status_code != 412:  # 412 = someone else updated it first
                    raise

        raise RuntimeError("Could not update the visit counter: too many concurrent writes")


def create_store_from_env():
    """Use Table Storage when STORAGE_TABLE_ENDPOINT is set, otherwise memory."""
    endpoint = os.environ.get("STORAGE_TABLE_ENDPOINT")
    if not endpoint:
        return InMemoryVisitStore()

    from azure.data.tables import TableClient
    from azure.identity import DefaultAzureCredential

    table_name = os.environ.get("STORAGE_TABLE_NAME", "visits")
    client = TableClient(
        endpoint=endpoint, table_name=table_name, credential=DefaultAzureCredential()
    )
    return TableVisitStore(client)
