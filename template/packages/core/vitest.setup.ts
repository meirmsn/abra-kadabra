// What: Vitest setup — install a minimal WebSocket stub on globalThis when missing.
// Why: @supabase/supabase-js >= 2.105 eagerly constructs RealtimeClient inside
//      createClient(), which calls getWebSocketConstructor() at construction time.
//      Node's default vitest env has no global WebSocket, so the very first unit
//      test that calls createClient() crashes before any assertion runs.
// Does NOT: Implement the WebSocket protocol — every method is a no-op. Tests that
//           actually exercise Realtime should mock the client surface, not rely on
//           this stub.

if (typeof globalThis.WebSocket === 'undefined') {
  class WebSocketStub {
    static readonly CONNECTING = 0;
    static readonly OPEN = 1;
    static readonly CLOSING = 2;
    static readonly CLOSED = 3;

    readyState = WebSocketStub.CLOSED;
    url = '';

    constructor(url: string | URL) {
      this.url = typeof url === 'string' ? url : url.toString();
    }

    send(): void {}
    close(): void {}
    addEventListener(): void {}
    removeEventListener(): void {}
    dispatchEvent(): boolean {
      return false;
    }
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (globalThis as any).WebSocket = WebSocketStub;
}
