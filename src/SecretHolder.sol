pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @notice This contract aims to store secret commitments for two parties, until one of them reveals it.
 * @author Felipe Buiras
 */
contract SecretHolder {
    struct Secret {
        bytes32 commitment;
        address partyA;
        address partyB;
        uint256 salt;
    }

    /**
     * @notice Structure holding the passed-in signatures
     * @dev This helps with destructuring the signature when it comes in via calldata.
     */
    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    /// @dev We use a uint256 here as an identifier instead of the salted hash on the off chance that we get a hash collision.
    mapping(uint256 => Secret) public secrets;
    uint256 public secretCount = 0;

    error InvalidMessageHash();
    error WrongSignatureCount();
    error BadSignature();

    event SecretStored(uint256 indexed id, bytes32 indexed commitment, address partyA, address partyB);
    event SecretRevealed(uint256 indexed id, address indexed revealer, bytes message);

    constructor() {}

    /**
     * @notice Commit a message hash to the contract. Must include signatures from both parties, which may
     *         be collected offchain.
     * @dev The secret hash must be obtained by hashing both the message and a provided salt. The salt will
     *      be kept in the contract's storage for later retrieval.
     * @param secretHash - (bytes32) Message hash: keccak256(abi.encode(message, salt))
     * @param salt - (uint256) The salt used to calculate the hash.
     * @param signatures - (Signature[2]) ECDSA signatures of the calculated hash from the involved parties.
     */
    function commitSecret(bytes32 secretHash, uint256 salt, bytes[] memory signatures) public {
        require(signatures.length == 2, WrongSignatureCount());

        address signerA = ECDSA.recover(secretHash, signatures[0]);
        address signerB = ECDSA.recover(secretHash, signatures[1]);

        secrets[secretCount] = Secret({commitment: secretHash, salt: salt, partyA: signerA, partyB: signerB});

        // TODO: emit
        emit SecretStored(secretCount, secretHash, signerA, signerB);

        secretCount++;
    }

    /**
     * @notice Reveal a previously commited secret.
     * @dev The stored secret metadata will be deleted from the contract after successful execution.
     * @param id - The identifier of the previously commited secret.
     * @param secretMessage - The commited message, without salting.
     * @param signature - Signature of the revealing party.
     */
    function revealSecret(uint256 id, bytes calldata secretMessage, bytes memory signature) public {
        Secret storage secret = secrets[id];

        bytes32 hash = keccak256(abi.encodePacked(secretMessage, secret.salt));
        require(hash == secret.commitment, InvalidMessageHash());

        address signer = ECDSA.recover(hash, signature);
        require(signer == secret.partyA || signer == secret.partyB, BadSignature());

        emit SecretRevealed(id, signer, secretMessage);

        delete secrets[id];
    }
}
