pragma solidity 0.8.26;

import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

/**
 * @notice This contract aims to store secret commitments for two parties, until one of them reveals it.
 * @author Felipe Buiras
 */
contract SecretHolder is EIP712 {
    bytes32 private constant SECRET_TYPEHASH = keccak256("Secret(bytes32 hash,uint256 salt)");
    bytes32 private constant REVEAL_TYPEHASH = keccak256("Reveal(uint256 id,bytes message)");

    struct Secret {
        bytes32 commitment;
        address partyA;
        address partyB;
        uint256 salt;
    }

    /// @dev We use a uint256 here as an identifier instead of the salted hash on the off chance that we get a hash collision.
    mapping(uint256 => Secret) public secrets;
    uint256 public secretCount = 0;

    event SecretStored(uint256 indexed id, bytes32 indexed commitment, address partyA, address partyB);
    event SecretRevealed(uint256 indexed id, address indexed revealer, bytes message);

    error InvalidMessageHash();
    error WrongSignatureCount();
    error BadSignature();

    constructor() EIP712("SecretHolder", "0.1") {}

    /**
     * @notice Commit a message hash to the contract. Must include signatures from both parties, which may
     *         be collected offchain.
     * @dev The secret hash must be obtained by hashing both the message and a provided salt. The salt will
     *      be kept in the contract's storage for later retrieval.
     * @param secretHash - (bytes32) Message hash: keccak256(abi.encode(message, salt))
     * @param salt - (uint256) The salt used to calculate the hash.
     * @param signatures - (Signature[2]) ECDSA signatures of the calculated hash from the involved parties.
     */
    function commitSecret(bytes32 secretHash, uint256 salt, bytes[] memory signatures) external {
        require(signatures.length == 2, WrongSignatureCount());

        bytes32 hash = buildCommitHash(secretHash, salt);

        address signerA = ECDSA.recover(hash, signatures[0]);
        address signerB = ECDSA.recover(hash, signatures[1]);

        secrets[secretCount] = Secret({commitment: secretHash, salt: salt, partyA: signerA, partyB: signerB});

        emit SecretStored(secretCount, secretHash, signerA, signerB);

        secretCount++;
    }

    function buildCommitHash(bytes32 secretHash, uint256 salt) public view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(SECRET_TYPEHASH, secretHash, salt));
        return _hashTypedDataV4(structHash);
    }

    /**
     * @notice Reveal a previously commited secret.
     * @dev The stored secret metadata will be deleted from the contract after successful execution.
     * @param id - The identifier of the previously commited secret.
     * @param secretMessage - The commited message, without salting.
     * @param signature - Signature of the revealing party.
     */
    function revealSecret(uint256 id, bytes memory secretMessage, bytes memory signature) external {
        Secret storage secret = secrets[id];

        bytes32 revealHash = buildRevealHash(id, secretMessage);

        address signer = ECDSA.recover(revealHash, signature);

        require(signer == secret.partyA || signer == secret.partyB, BadSignature());

        bytes32 hash = keccak256(abi.encodePacked(secretMessage, secret.salt));
        require(hash == secret.commitment, InvalidMessageHash());

        emit SecretRevealed(id, signer, secretMessage);

        delete secrets[id];
    }

    function buildRevealHash(uint256 id, bytes memory secretMessage) public view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(REVEAL_TYPEHASH, id, secretMessage));
        return _hashTypedDataV4(structHash);
    }
}
