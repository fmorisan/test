pragma solidity 0.8.26;

import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

/**
 * @notice This contract aims to store secret commitments for two parties, until one of them reveals it.
 * @author Felipe Buiras
 */
contract SecretHolder is EIP712 {
    bytes32 private constant SECRET_TYPEHASH = keccak256("Secret(bytes32 hash,uint256 salt,address partyA,address partyB,uint256 nonceA,uint256 nonceB)");

    struct Secret {
        bytes32 commitment;
        address partyA;
        address partyB;
        uint256 salt;
    }

    /// @dev We use a uint256 here as an identifier instead of the salted hash on the off chance that we get a hash collision.
    mapping(uint256 => Secret) public secrets;
    uint256 public secretCount = 0;

    // @dev We must know if a signature has already been used in order to prevent replay attacks.
    mapping(address => uint256) public nonces;

    event SecretStored(uint256 indexed id, bytes32 indexed commitment, address partyA, address partyB);
    event SecretRevealed(uint256 indexed id, address indexed revealer, bytes message);

    error InvalidMessageHash();
    error WrongSignatureCount();
    error ThirdPartyCantReveal();
    error InvalidNonce();
    error InvalidSignature(address expectedSigner);

    constructor() EIP712("SecretHolder", "0.1") {}

    /**
     * @notice Commit a message hash to the contract. Must include signatures from both parties, which may
     *         be collected offchain.
     * @dev The secret hash must be obtained by hashing both the message and a provided salt. The salt will
     *      be kept in the contract's storage for later retrieval.
     * @param secretHash - (bytes32) Message hash: keccak256(abi.encode(message, salt))
     * @param salt - (uint256) The salt used to calculate the hash.
     * @param partyA - (address) One of the signing parties
     * @param partyB - (address) The other of the signing parties
     * @param signatures - (Signature[2]) ECDSA signatures of the calculated hash from the involved parties.
     */
    function commitSecret(bytes32 secretHash, uint256 salt, address partyA, address partyB, bytes[] memory signatures) external {
        require(signatures.length == 2, WrongSignatureCount());

        bytes32 hash = buildCommitHash(secretHash, salt, partyA, partyB, nonces[partyA], nonces[partyB]);

        address signerA = ECDSA.recover(hash, signatures[0]);
        address signerB = ECDSA.recover(hash, signatures[1]);

        require(signerA == partyA, InvalidSignature(partyA));
        require(signerB == partyB, InvalidSignature(partyB));

        nonces[partyA]++;
        nonces[partyB]++;

        secrets[secretCount] = Secret({commitment: secretHash, salt: salt, partyA: signerA, partyB: signerB});

        emit SecretStored(secretCount, secretHash, signerA, signerB);

        secretCount++;
        
    }

    function buildCommitHash(bytes32 secretHash, uint256 salt, address partyA, address partyB, uint256 nonceA, uint256 nonceB) public view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(SECRET_TYPEHASH, secretHash, salt, partyA, partyB, nonceA, nonceB));
        return _hashTypedDataV4(structHash);
    }

    /**
     * @notice Reveal a previously commited secret.
     * @dev The stored secret metadata will be deleted from the contract after successful execution.
     * @param id - The identifier of the previously commited secret.
     * @param secretMessage - The commited message, without salting.
     */
    function revealSecret(uint256 id, string memory secretMessage) external {
        Secret storage secret = secrets[id];
        require(msg.sender == secret.partyA || msg.sender == secret.partyB, ThirdPartyCantReveal());

        bytes32 hash = keccak256(abi.encodePacked(secretMessage, secret.salt));
        require(hash == secret.commitment, InvalidMessageHash());

        emit SecretRevealed(id, msg.sender, bytes(secretMessage));
        delete secrets[id];
    }
}
