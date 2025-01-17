## Eco take-home Exercise

### Exercise
Assume that we have a need for a contract that allows any two parties to store a secret on chain.
This could be used to prove that the two parties had agreed on something at a given block. At
some later block we would want either one of the parties to be able to reveal what the secret is
on-chain, and then delete the original agreement from the chain.  
Write a solidity contract that allows for participants to store a secret that they have both
agreed to. The contract should allow any two parties to agree and sign off on a secret that can
then be stored on-chain. The secret should be stored in such a way that it should not be possible
to know its value by observing it. At any point, either of the two parties should be able to reveal
the actual value of the secret. When the secret is revealed, the contract should emit an event of
who was the party that revealed it and its real value, and then the stored secret should be
deleted. When writing the contract, assume that when the secret is first registered on-chain, it has
to be in a single transaction because we want to guarantee that it takes place in the same block.

### Hint
Look into how to generate signatures off-chain and how those signatures can be validated on-chain.

## Solution
This repo consists of two parts:
- A Foundry project containing the underlying smart contract and its tests.
- A simple React frontend that allows users to pass signatures to each other via location fragments.

## Runnning
You may run the project locally by executing
```bash
$ ./setup_test_environment.sh
```

This will start a local Anvil node, deploy the contract and bring the UI up.

## Development choices
- The contract uses EIP-712 signatures at the time of secret commitment, in order to both ensure that there is a definite block number for the commitment and allow parties without ETH to sign commitments with each other.
- The contract requires one of the parties to execute an onchain transaction in order to reveal the message.
    - I intended this to be done via signatures as well, but I couldn't get the hashing for the Reveal messages quite right.
- Revealed messages have their metadata removed from storage. This aims to fulfill the `the stored secret should be deleted` request, but note that the secret would still be available when looking at the emitted events.
- Users may commit a message with themselves by specifying the same signature twice. This was not specified in the exercise specs.

## Known issues (frontend)
Since the frontend aims to be a proof of concept for interaction with the contract, some issues (mainly UX) are left unresolved.
- Users have to manually copy the URL to send over to their counterparty.
- React Router's BASE URL and HOSTNAME are set to the Vite default fo http://localhost:5173
- Styles are a bit broken

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
