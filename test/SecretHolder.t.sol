// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SecretHolder} from "../src/SecretHolder.sol";

contract CounterTest is Test {
    SecretHolder public secretHolder;

    /// @dev Actors
    uint256 alice_pk;
    uint256 bob_pk;
    uint256 carl_pk;

    address alice;
    address bob;
    address carl;

    function setUp() public {
        secretHolder = new SecretHolder();
        (alice, alice_pk) = makeAddrAndKey("alice");
        (bob, bob_pk) = makeAddrAndKey("bob");
        (carl, carl_pk) = makeAddrAndKey("carl");
    }

    function test_constructed() public view {
        assertEq(secretHolder.secretCount(), 0);
    }

    function _commitMessage(bytes memory message, uint256 salt) internal returns (uint256 id) {
        bytes32 secretHash = keccak256(abi.encodePacked(message, salt));

        uint256 alice_nonce = secretHolder.nonces(alice);
        uint256 bob_nonce = secretHolder.nonces(bob);

        bytes32 structHash = secretHolder.buildCommitHash(secretHash, salt, alice, bob, alice_nonce, bob_nonce);

        bytes[] memory signatures = new bytes[](2);
        (uint8 alice_v, bytes32 alice_r, bytes32 alice_s) = vm.sign(alice_pk, structHash);
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(bob_pk, structHash);

        // NOTE: OZ's ECDSA library expects the signature to be formed this way.
        signatures[0] = abi.encodePacked(alice_r, alice_s, alice_v);
        signatures[1] = abi.encodePacked(bob_r, bob_s, bob_v);

        secretHolder.commitSecret(secretHash, salt, alice, bob, signatures);

        id = secretHolder.secretCount() - 1;
    }

    function test_commmit() public {
        _commitMessage("hello", 0xFF);
    }

    function test_commit_badnonce() public {
        _commitMessage("hello", 0xFF);

        bytes memory message = "hello";
        uint256 salt = 0xff;

        bytes32 secretHash = keccak256(abi.encodePacked(message, salt));

        // Lets reuse alice's nonce
        uint256 alice_nonce = 0;  // NOTE: was secretHolder.nonces(alice);
        uint256 bob_nonce = secretHolder.nonces(bob);

        bytes32 structHash = secretHolder.buildCommitHash(secretHash, salt, alice, bob, alice_nonce, bob_nonce);

        bytes[] memory signatures = new bytes[](2);
        (uint8 alice_v, bytes32 alice_r, bytes32 alice_s) = vm.sign(alice_pk, structHash);
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(bob_pk, structHash);

        // NOTE: OZ's ECDSA library expects the signature to be formed this way.
        signatures[0] = abi.encodePacked(alice_r, alice_s, alice_v);
        signatures[1] = abi.encodePacked(bob_r, bob_s, bob_v);

        vm.expectRevert(abi.encodeWithSelector(SecretHolder.InvalidSignature.selector, alice));
        secretHolder.commitSecret(secretHash, salt, alice, bob, signatures);
    }

    function test_reveal() public {
        uint256 salt = 0xFFFFFFFF;
        uint256 secretId = _commitMessage("123123", salt);

        // Let's have bob reveal the message
        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit SecretHolder.SecretRevealed(secretId, bob, "123123");
        secretHolder.revealSecret(secretId, "123123");

        // NOTE: Check that the secret metadata has been removed from contract storage.
        (bytes32 commitment, address partyA, address partyB, uint256 retrieved_salt) = secretHolder.secrets(secretId);
        assertEq(commitment, bytes32(0));
        assertEq(partyA, address(0));
        assertEq(partyB, address(0));
        assertEq(retrieved_salt, 0);
    }

    function test_reveal_badMessage() public {
        uint256 secretId = _commitMessage("This is a test", 0xFFFF_FFFF);

        // Let's have bob reveal a different message
        vm.prank(bob);
        vm.expectRevert(SecretHolder.InvalidMessageHash.selector);
        secretHolder.revealSecret(secretId, "This is another test");
    }

    function testFuzz_revealed_byThirdParty(address revealer) public {
        vm.assume(revealer != alice);
        vm.assume(revealer != bob);
        uint256 secretId = _commitMessage("This is a test", 0xFFFF_FFFF);

        vm.prank(revealer);
        vm.expectRevert(SecretHolder.ThirdPartyCantReveal.selector);
        secretHolder.revealSecret(secretId, "This is a test");
    }

    function test_revealSigned() public {
        uint256 secretId = _commitMessage("This is a test", 0xFFFF_FFFF);
        uint256 aliceNonce = secretHolder.nonces(alice);

        bytes32 structHash = secretHolder.buildRevealHash("This is a test", secretId, aliceNonce);
        (uint8 alice_v, bytes32 alice_r, bytes32 alice_s) = vm.sign(alice_pk, structHash);

        secretHolder.revealSecretSigned(secretId, "This is a test", aliceNonce, abi.encodePacked(alice_r, alice_s, alice_v));
    }


    function test_revealSigned_cannotReuseSignature() public {
        uint256 secretId = _commitMessage("This is a test", 0xFFFF_FFFF);
        uint256 aliceNonce = secretHolder.nonces(alice);

        bytes32 structHash = secretHolder.buildRevealHash("This is a test", secretId, aliceNonce);
        (uint8 alice_v, bytes32 alice_r, bytes32 alice_s) = vm.sign(alice_pk, structHash);

        secretHolder.revealSecretSigned(secretId, "This is a test", aliceNonce, abi.encodePacked(alice_r, alice_s, alice_v));

        vm.expectRevert(SecretHolder.InvalidNonce.selector);
        secretHolder.revealSecretSigned(secretId, "This is a test", aliceNonce, abi.encodePacked(alice_r, alice_s, alice_v));
    }

    function test_RevertIf_invalidMessage_revealSigned() public {
        uint256 secretId = _commitMessage("This is a test", 0xFFFF_FFFF);
        uint256 aliceNonce = secretHolder.nonces(alice);

        bytes32 structHash = secretHolder.buildRevealHash("THIS IS THE WRONG MESSAGE", secretId, aliceNonce);
        (uint8 alice_v, bytes32 alice_r, bytes32 alice_s) = vm.sign(alice_pk, structHash);

        vm.expectRevert(SecretHolder.InvalidMessageHash.selector);
        secretHolder.revealSecretSigned(secretId, "THIS IS THE WRONG MESSAGE", aliceNonce, abi.encodePacked(alice_r, alice_s, alice_v));
    }

    function test_RevertIf_signedByThirdParty_revealSigned() public {
        uint256 secretId = _commitMessage("This is a test", 0xFFFF_FFFF);
        uint256 carlNonce = secretHolder.nonces(carl);

        bytes32 structHash = secretHolder.buildRevealHash("THIS IS THE WRONG MESSAGE", secretId, carlNonce);
        (uint8 carl_v, bytes32 carl_r, bytes32 carl_s) = vm.sign(carl_pk, structHash);

        vm.expectRevert(SecretHolder.ThirdPartyCantReveal.selector);
        secretHolder.revealSecretSigned(secretId, "THIS IS THE WRONG MESSAGE", carlNonce, abi.encodePacked(carl_r, carl_s, carl_v));
    }
}
