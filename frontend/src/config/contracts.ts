export const CONTRACT_ABI = [
    "function commitSecret(bytes32 hash, uint256 salt, address partyA, address partyB, bytes[] signatures) public",
    "function revealSecret(uint256 id, string memory message) public",
    "function revealSecretSigned(uint256 id, string memory message, uint256 nonce, bytes memory signature) public",
    "function secrets(uint256 id) public view returns (bytes32 commitment, address partyA, address partyB, uint256 salt)",
    "function secretCount() public view returns (uint256)",
    "function nonces(address who) public view returns (uint256)",
] as const

export const VERIFYING_CONTRACTS: Record<number, `0x${string}`> = {
    84532: "0x5924d1732aAB72e92C0B35cc3416d55D612e1162",
    31337: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
}

export const SIGN_TYPES = {
    Secret: [
        {name: 'hash', type: 'bytes32'},
        {name: 'salt', type: 'uint256'},
        {name: 'partyA', type: 'address'},
        {name: 'partyB', type: 'address'},
        {name: 'nonceA', type: 'uint256'},
        {name: 'nonceB', type: 'uint256'},
    ],
    Reveal: [
        {name: 'id', type: 'uint256'},
        {name: 'message', type: 'bytes'},
        {name: 'nonce', type: 'uint256'},
    ],
    EIP712Domain: [
        {name: 'name', type: 'string'},
        {name: 'version', type: 'string'},
        {name: 'chainId', type: 'uint256'},
        {name: 'verifyingContract', type: 'address'},
    ]
} as const
