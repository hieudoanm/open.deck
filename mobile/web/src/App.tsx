import { useState } from "react";
import { ConnectView, type Creds } from "./components/ConnectView";
import { DeckView } from "./components/DeckView";

export default function App() {
  const params = new URLSearchParams(window.location.search);
  const [creds, setCreds] = useState<Creds>({
    host: params.get("host") || "127.0.0.1",
    port: params.get("port") || "47821",
    token: params.get("token") || "",
  });
  const [connected, setConnected] = useState(() => !!params.get("token"));
  const [status, setStatus] = useState("");
  const [statusCls, setStatusCls] = useState("");

  const close = () => {
    setStatus("Disconnected");
    setStatusCls("");
    setConnected(false);
  };

  if (connected) {
    return (
      <DeckView
        host={creds.host.trim() || "127.0.0.1"}
        port={creds.port.trim() || "47821"}
        token={creds.token.trim()}
        onClose={close}
      />
    );
  }

  return (
    <ConnectView
      creds={creds}
      onChange={setCreds}
      onConnect={() => setConnected(true)}
      status={status}
      statusCls={statusCls}
    />
  );
}
