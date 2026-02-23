from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any, Iterable

import psycopg2
from psycopg2.extras import RealDictCursor


def _is_postgres_url(db_url: str) -> bool:
    normalized = (db_url or "").strip().lower()
    return normalized.startswith("postgresql://") or normalized.startswith("postgres://")


def _translate_sql(query: str) -> str:
    lowered = query.lower()
    if "?" in query:
        raise ValueError("Use PostgreSQL placeholders (%s), not '?'.")
    if "ifnull(" in lowered:
        raise ValueError("Use PostgreSQL COALESCE(...) instead of ifnull(...).")
    return query


def _split_statements(script: str) -> list[str]:
    statements: list[str] = []
    current: list[str] = []
    in_single = False
    in_double = False
    prev = ""
    for ch in script:
        if ch == "'" and not in_double and prev != "\\":
            in_single = not in_single
        elif ch == '"' and not in_single and prev != "\\":
            in_double = not in_double
        if ch == ";" and not in_single and not in_double:
            stmt = "".join(current).strip()
            if stmt:
                statements.append(stmt)
            current = []
        else:
            current.append(ch)
        prev = ch
    trailing = "".join(current).strip()
    if trailing:
        statements.append(trailing)
    return statements


class CursorCompat:
    def __init__(self, cursor):
        self._cursor = cursor

    def execute(self, query: str, params: Iterable[Any] | None = None):
        self._cursor.execute(_translate_sql(query), tuple(params or ()))
        return self

    def fetchone(self):
        return self._cursor.fetchone()

    def fetchall(self):
        return self._cursor.fetchall()

    @property
    def rowcount(self) -> int:
        return self._cursor.rowcount

    @property
    def lastrowid(self):
        return self._cursor.lastrowid

    def close(self) -> None:
        self._cursor.close()


class ConnectionCompat:
    def __init__(self, conn):
        self._conn = conn

    def execute(self, query: str, params: Iterable[Any] | None = None) -> CursorCompat:
        cur = self._conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(_translate_sql(query), tuple(params or ()))
        return CursorCompat(cur)

    def cursor(self) -> CursorCompat:
        return CursorCompat(self._conn.cursor(cursor_factory=RealDictCursor))

    def executescript(self, script: str) -> None:
        cur = self._conn.cursor()
        try:
            for stmt in _split_statements(script):
                cur.execute(_translate_sql(stmt))
        finally:
            cur.close()

    def commit(self) -> None:
        self._conn.commit()

    def rollback(self) -> None:
        self._conn.rollback()

    def close(self) -> None:
        self._conn.close()


@dataclass
class _ConnManager:
    db_url: str
    _raw_conn: Any | None = None
    _compat_conn: ConnectionCompat | None = None

    def __enter__(self) -> ConnectionCompat:
        if not _is_postgres_url(self.db_url):
            raise RuntimeError(
                "ECD_DATABASE_URL must be a PostgreSQL URL, for example "
                "'postgresql://postgres:postgres@127.0.0.1:5432/ecd_data'."
            )
        timeout_raw = os.getenv("ECD_PG_CONNECT_TIMEOUT", "5")
        try:
            timeout_seconds = max(1, int(timeout_raw))
        except ValueError:
            timeout_seconds = 5
        self._raw_conn = psycopg2.connect(self.db_url, connect_timeout=timeout_seconds)
        self._compat_conn = ConnectionCompat(self._raw_conn)
        return self._compat_conn

    def __exit__(self, exc_type, exc, tb) -> bool:
        if self._raw_conn is None:
            return False
        try:
            if exc_type is None:
                self._raw_conn.commit()
            else:
                self._raw_conn.rollback()
        finally:
            self._raw_conn.close()
        return False


def get_conn(db_url: str) -> _ConnManager:
    return _ConnManager(db_url=db_url)
