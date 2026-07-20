import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.duelvault.app',
  appName: 'Duel Vault',
  webDir: 'dist',
  server: {
    androidScheme: 'https',
  },
}

export default config
