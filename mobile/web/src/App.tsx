import { useState } from "react";
import { ConnectPage, type Creds } from "./pages/ConnectPage";
import { DeckPage } from "./pages/DeckPage";

const App = () => {
  const params = new URLSearchParams(window.location.search);
  const isDev = import.meta.env.DEV;
  const [creds, setCreds] = useState<Creds>({
    host: params.get("host") || import.meta.env.VITE_HOST || "127.0.0.1",
    port: params.get("port") || import.meta.env.VITE_PORT || "47821",
    token: params.get("token") || import.meta.env.VITE_TOKEN || "",
  });
  // Dev mode skips the connect form and goes straight to the dashboard.
  const [connected, setConnected] = useState(
    () => isDev || !!params.get("token"),
  );
  const [status, setStatus] = useState("");
  const [statusCls, setStatusCls] = useState("");

  const close = () => {
    setStatus("Disconnected");
    setStatusCls("");
    setConnected(false);
  };

  if (connected) {
    return (
      <DeckPage
        host={creds.host.trim() || "127.0.0.1"}
        port={creds.port.trim() || "47821"}
        token={creds.token.trim()}
        onClose={close}
      />
    );
  }

  return (
    <ConnectPage
      creds={creds}
      onChange={setCreds}
      onConnect={() => setConnected(true)}
      status={status}
      statusCls={statusCls}
    />
  );
};

export default App;
