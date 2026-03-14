import { useState, useEffect, useRef, useCallback } from "react";

/** Generic data-fetching hook with loading/error states. */
export function useFetch<T>(fetcher: () => Promise<T>, deps: unknown[] = []) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(() => {
    setLoading(true);
    setError(null);
    fetcher()
      .then(setData)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, deps);

  useEffect(() => { reload(); }, [reload]);

  return { data, loading, error, reload };
}

/** WebSocket hook for live feed. */
export function useLiveFeed() {
  const [events, setEvents] = useState<LiveEvent[]>([]);
  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const ws = new WebSocket(`${protocol}//${window.location.host}/ws`);
    wsRef.current = ws;

    ws.onmessage = (e) => {
      const event = JSON.parse(e.data) as LiveEvent;
      setEvents((prev) => [event, ...prev].slice(0, 100));
    };

    ws.onclose = () => {
      // Reconnect after 3s
      setTimeout(() => {
        wsRef.current = null;
      }, 3000);
    };

    return () => { ws.close(); };
  }, []);

  return events;
}

export interface LiveEvent {
  type: string;
  data: Record<string, unknown>;
  timestamp: string;
}
