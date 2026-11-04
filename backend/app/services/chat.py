"""
In-memory websocket rooms, one room per consultation.

Fine for a single API instance. If we scale out to more than one worker this
needs redis pub/sub, noted in docs/architecture.md.
"""

import asyncio
from collections import defaultdict

from fastapi import WebSocket


class ChatHub:
    def __init__(self):
        self.rooms: dict[int, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def join(self, room: int, ws: WebSocket):
        await ws.accept()
        async with self._lock:
            self.rooms[room].add(ws)

    async def leave(self, room: int, ws: WebSocket):
        async with self._lock:
            self.rooms[room].discard(ws)
            if not self.rooms[room]:
                self.rooms.pop(room, None)

    async def broadcast(self, room: int, payload: dict):
        dead = []
        for ws in list(self.rooms.get(room, ())):
            try:
                await ws.send_json(payload)
            except Exception:
                dead.append(ws)
        for ws in dead:
            await self.leave(room, ws)

    def online(self, room: int) -> int:
        return len(self.rooms.get(room, ()))


hub = ChatHub()
