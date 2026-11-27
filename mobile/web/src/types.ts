export interface HelloMsg {
  type: 'hello';
  desktop_width: number;
  desktop_height: number;
  stream_width: number;
  stream_height: number;
  fps: number;
}

export interface StatsMsg {
  type?: string;
  cpu_percent: number | null;
  mem_used: number;
  mem_total: number;
  swap_used: number;
  swap_total: number;
  disk_used: number;
  disk_total: number;
  net_rx_rate: number;
  net_tx_rate: number;
  uptime_secs: number;
  battery_percent: number | null;
  battery_state: string | null;
  net_interfaces: { name: string }[];
}

export interface StatusMsg {
  clients: number;
  desktop_width: number;
  desktop_height: number;
  fps: number;
}

export interface PortEntry {
  protocol: string;
  address: string;
  port: number;
  state: string;
  pid: number;
  process: string;
}

export interface AppEntry {
  pid: number;
  name: string;
  cpu_percent: number;
  mem_bytes: number;
}
