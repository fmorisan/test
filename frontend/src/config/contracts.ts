export const CONTRACT_ABI = [
    "function commitSecret(bytes32 hash, uint256 salt, uint256 nonceA, uint256 nonceB, bytes[] signatures) public",
    "function revealSecret(uint256 id, string memory message) public",
    "function secrets(uint256 id) public view returns (bytes32 commitment, address partyA, address partyB, uint256 salt)",
    "function secretCount() public view returns (uint256)",
    "function nonces(address who) public view returns (uint256)",
] as const

export const VERIFYING_CONTRACTS: Record<number, `0x${string}`> = {
    84532: "0x5a7a9c375B5776e46bBd13931BF6CDa887D6E29d",
    31337: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
}

export const SIGN_TYPES = {
    Secret: [
        {name: 'hash', type: 'bytes32'},
        {name: 'salt', type: 'uint256'},
        {name: 'nonce', type: 'uint256'},
    ],
    EIP712Domain: [
        {name: 'name', type: 'string'},
        {name: 'version', type: 'string'},
        {name: 'chainId', type: 'uint256'},
        {name: 'verifyingContract', type: 'address'},
    ]
} as const
