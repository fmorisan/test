pragma solidity ^0.8.20;

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
    uint256 secretCount;

    error WrongSignatureCount();
    error InvalidSignature();

    event SecretStored(uint256 indexed id, bytes32 indexed commitment, address partyA, address partyB);
    event SecretRevealed(uint256 indexed id, address indexed revealer, bytes message);
    event SecretLeaked(uint256 indexed id, address indexed revealer);

    constructor() {
        secretCount = 0;
    }

    /**
     * @notice Commit a message hash to the contract. Must include signatures from both parties, which may
     *         be collected offchain.
     * @dev The secret hash must be obtained by hashing both the message and a provided salt. The salt will
     *      be kept in the contract's storage for later retrieval.
     * @param secretHash - (bytes32) Message hash: keccak256(abi.encode(message, salt))
     * @param salt - (uint256) The salt used to calculate the hash.
     * @param signatures - (Signature[2]) ECDSA signatures of the calculated hash from the involved parties.
     */
    function commitSecret(bytes32 secretHash, uint256 salt, Signature[] calldata signatures) public {
        require(signatures.length == 2, WrongSignatureCount());
        address signerA = ecrecover(secretHash, signatures[0].v, signatures[0].r, signatures[0].s);
        address signerB = ecrecover(secretHash, signatures[1].v, signatures[2].r, signatures[3].s);

        require(signerA != address(0), InvalidSignature());
        require(signerB != address(0), InvalidSignature());

        secrets[secretCount] = Secret({commitment: secretHash, salt: salt, partyA: signerA, partyB: signerB});

        // TODO: emit
        emit SecretStored(secretCount, secretHash, signerA, signerB);

        secretCount++;
    }

    /**
     * @notice Reveal a previously commited secret.
     * @dev The stored hash and salt will be deleted from the contract after successful execution.
     *      If, by any chance, a third party can provide a valid signature for the commited hash,
     *      we can assume the message was leaked - and there's not much we can do since the message
     *      will already be revealed for the whole world in calldata anyways.
     * @param id - The identifier of the previously commited secret.
     * @param secretMessage - The commited message, without salting.
     * @param signature - Signature of the revealing party.
     */
    function revealSecret(uint256 id, bytes calldata secretMessage, Signature calldata signature) public {
        Secret storage secret = secrets[id];

        bytes32 hash = keccak256(abi.encode(secretMessage, secret.salt));

        address signer = ecrecover(hash, signature.v, signature.r, signature.s);
        require(signer != address(0), InvalidSignature());

        // NOTE: If a third party possesses the message used to generate the hash...
        //       then the two parties are in *big* trouble. We can't really do anything about that.
        //       Best we can do, is alert them by raising an event.
        emit SecretRevealed(id, signer, secretMessage);
        if (signer != secret.partyA && signer != secret.partyB) {
            emit SecretLeaked(id, signer);
        }

        delete secrets[id];
    }
}
