#!/usr/bin/env bash

# Start Anvil
anvil &

# Build the contracts using --via-ir
forge build --via-ir

# Deploy the SecretHolder contract to out local devnet
forge create src/SecretHolder.sol:SecretHolder --unlocked --from 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast --rpc-url http://localhost:8545

cd frontend
pnpm i
pnpm dev
