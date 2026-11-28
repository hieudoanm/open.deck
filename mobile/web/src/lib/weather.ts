// Port of the ClockCities list + Open-Meteo fetch shared with the mobile apps.

export interface ClockCity {
  id: number;
  label: string;
  country: string;
  latitude: number;
  longitude: number;
}

export const CITIES: ClockCity[] = [
  {
    id: 0,
    label: "Los Angeles",
    country: "United States",
    latitude: 34.0522,
    longitude: -118.2437,
  },
  {
    id: 1,
    label: "Dallas",
    country: "United States",
    latitude: 32.7767,
    longitude: -96.797,
  },
  {
    id: 2,
    label: "New York",
    country: "United States",
    latitude: 40.7128,
    longitude: -74.006,
  },
  {
    id: 3,
    label: "London",
    country: "United Kingdom",
    latitude: 51.5072,
    longitude: -0.1276,
  },
  {
    id: 4,
    label: "Frankfurt",
    country: "Germany",
    latitude: 50.1109,
    longitude: 8.6821,
  },
  {
    id: 5,
    label: "Paris",
    country: "France",
    latitude: 48.8566,
    longitude: 2.3522,
  },
  {
    id: 6,
    label: "Helsinki",
    country: "Finland",
    latitude: 60.1695,
    longitude: 24.9354,
  },
  {
    id: 7,
    label: "Dubai",
    country: "United Arab Emirates",
    latitude: 25.2048,
    longitude: 55.2708,
  },
  {
    id: 8,
    label: "Bangkok",
    country: "Thailand",
    latitude: 13.7563,
    longitude: 100.5018,
  },
  {
    id: 9,
    label: "Ho Chi Minh City",
    country: "Vietnam",
    latitude: 10.8231,
    longitude: 106.6297,
  },
  {
    id: 10,
    label: "Hanoi",
    country: "Vietnam",
    latitude: 21.0285,
    longitude: 105.8542,
  },
  {
    id: 11,
    label: "Da Nang",
    country: "Vietnam",
    latitude: 16.0544,
    longitude: 108.2022,
  },
  {
    id: 12,
    label: "Singapore",
    country: "Singapore",
    latitude: 1.3521,
    longitude: 103.8198,
  },
  {
    id: 13,
    label: "Tokyo",
    country: "Japan",
    latitude: 35.6895,
    longitude: 139.6917,
  },
  {
    id: 14,
    label: "Sydney",
    country: "Australia",
    latitude: -33.8688,
    longitude: 151.2093,
  },
  {
    id: 15,
    label: "Melbourne",
    country: "Australia",
    latitude: -37.8136,
    longitude: 144.9631,
  },
  {
    id: 16,
    label: "Birmingham",
    country: "United States",
    latitude: 33.5186,
    longitude: -86.8104,
  },
];

export interface WeatherSample {
  tempC: number;
  feelsC: number;
  humidity: number;
  windKmh: number;
  code: number;
  tmax: number;
  tmin: number;
}

const CONDITIONS: Record<number, string> = {
  0: "Clear sky",
  1: "Mainly clear",
  2: "Partly cloudy",
  3: "Overcast",
  45: "Fog",
  48: "Rime fog",
  51: "Light drizzle",
  53: "Drizzle",
  55: "Dense drizzle",
  61: "Light rain",
  63: "Moderate rain",
  65: "Heavy rain",
  71: "Light snow",
  73: "Moderate snow",
  75: "Heavy snow",
  80: "Light showers",
  81: "Showers",
  82: "Heavy showers",
  95: "Thunderstorm",
  96: "Storm w/ hail",
  99: "Heavy storm",
};

export const conditionText = (code: number): string => {
  return CONDITIONS[code] ?? "Unknown";
};

interface Payload {
  current?: {
    temperature_2m?: number;
    apparent_temperature?: number;
    relative_humidity_2m?: number;
    weather_code?: number;
    wind_speed_10m?: number;
  };
  daily?: {
    temperature_2m_max?: number[];
    temperature_2m_min?: number[];
  };
}

export const fetchWeather = async (city: ClockCity): Promise<WeatherSample> => {
  const params = new URLSearchParams({
    latitude: String(city.latitude),
    longitude: String(city.longitude),
    current:
      "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m",
    daily: "temperature_2m_max,temperature_2m_min",
    timezone: "auto",
    forecast_days: "1",
  });
  const r = await fetch(`https://api.open-meteo.com/v1/forecast?${params}`);
  if (!r.ok) throw new Error(`open-meteo ${r.status}`);
  const j = (await r.json()) as Payload;
  const c = j.current;
  if (!c?.temperature_2m || c.weather_code == null) {
    throw new Error("bad open-meteo payload");
  }
  return {
    tempC: c.temperature_2m,
    feelsC: c.apparent_temperature ?? c.temperature_2m,
    humidity: c.relative_humidity_2m ?? 0,
    windKmh: c.wind_speed_10m ?? 0,
    code: c.weather_code,
    tmax: j.daily?.temperature_2m_max?.[0] ?? c.temperature_2m,
    tmin: j.daily?.temperature_2m_min?.[0] ?? c.temperature_2m,
  };
};
