import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { baseSepolia, anvil } from 'wagmi/chains'

export const config = getDefaultConfig({
    appName: "Secrets",
    projectId: "PROJECT_ID",
    chains: [ baseSepolia, anvil ],
    ssr: false
})
