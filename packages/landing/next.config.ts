import type { NextConfig } from 'next';

const NODE_ENV = process.env.NODE_ENV ?? 'development';
const BASE_PATH = '/open.deck';

const nextConfig: NextConfig = {
  turbopack: {
    rules: {
      '*.css': {
        loaders: ['@tailwindcss/turbopack'],
      },
    },
  },

  output: 'export',
  trailingSlash: true,
  // GitHub Pages project site lives under /open.deck/
  basePath: NODE_ENV === 'production' ? BASE_PATH : '',
  assetPrefix: NODE_ENV === 'production' ? BASE_PATH : '',
  images: { unoptimized: true },
};

export default nextConfig;
