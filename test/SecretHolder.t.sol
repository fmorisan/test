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

    function testFuzz_commit(uint256 salt) public {
        uint256 secretCountBefore = secretHolder.secretCount();
        bytes memory message = "This is a test message";
        bytes32 hash = keccak256(abi.encodePacked(message, salt));

        bytes[] memory signatures = new bytes[](2);
        (uint8 alice_v, bytes32 alice_r, bytes32 alice_s) = vm.sign(alice_pk, hash);
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(bob_pk, hash);

        // NOTE: OZ's ECDSA library expects the signature to be formed this way.
        signatures[0] = abi.encodePacked(alice_r, alice_s, alice_v);
        signatures[1] = abi.encodePacked(bob_r, bob_s, bob_v);

        vm.expectEmit(false, true, true, true);
        emit SecretHolder.SecretStored(0, hash, alice, bob);
        secretHolder.commitSecret(hash, salt, signatures);

        assertEq(secretHolder.secretCount(), secretCountBefore + 1);
    }

    function _commitMessage(bytes memory message, uint256 salt) internal returns (uint256 id) {
        bytes32 hash = keccak256(abi.encodePacked(message, salt));

        bytes[] memory signatures = new bytes[](2);
        (uint8 alice_v, bytes32 alice_r, bytes32 alice_s) = vm.sign(alice_pk, hash);
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(bob_pk, hash);

        // NOTE: OZ's ECDSA library expects the signature to be formed this way.
        signatures[0] = abi.encodePacked(alice_r, alice_s, alice_v);
        signatures[1] = abi.encodePacked(bob_r, bob_s, bob_v);

        secretHolder.commitSecret(hash, salt, signatures);

        id = secretHolder.secretCount() - 1;
    }

    function test_reveal() public {
        uint256 salt = 0xFFFF_FFFF;
        uint256 secretId = _commitMessage("This is a test", salt);

        // Let's have bob reveal the message
        bytes32 hash = keccak256(abi.encodePacked("This is a test", salt));
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(bob_pk, hash);

        vm.expectEmit(true, true, true, true);
        emit SecretHolder.SecretRevealed(secretId, bob, "This is a test");
        secretHolder.revealSecret(secretId, "This is a test", abi.encodePacked(bob_r, bob_s, bob_v));
    }

    function testFail_reveal_badMessage() public {
        uint256 secretId = _commitMessage("This is a test", 0xFFFF_FFFF);

        // Let's have bob reveal a different message
        bytes32 hash = keccak256(abi.encode("This is another test", 0xFFFF_FFFF));
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(bob_pk, hash);

        secretHolder.revealSecret(secretId, "This is another test", abi.encodePacked(bob_r, bob_s, bob_v));
    }

    function testFail_reveal_badSignature() public {
        uint256 secretId = _commitMessage("This is a test", 0xFFFF_FFFF);

        // Let's have bob sign something else entirely
        bytes32 hash = keccak256(abi.encode("This is another test", 0xFFFF_FFFF));
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(bob_pk, hash);

        secretHolder.revealSecret(secretId, "This is a test", abi.encodePacked(bob_r, bob_s, bob_v));
    }

    function testFuzz_revealed_byThirdParty(uint256 pk) public {
        vm.assume(pk != alice_pk);
        vm.assume(pk != bob_pk);
        // ECDSA: pk should be in this range to be a valid key
        vm.assume(pk > 0);
        vm.assume(pk < 115792089237316195423570985008687907852837564279074904382605163141518161494337);

        uint256 secretId = _commitMessage("This is a test", 0xFFFF_FFFF);

        bytes32 hash = keccak256(abi.encode("This is a test", 0xFFFF_FFFF));
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(pk, hash);

        vm.expectRevert();
        secretHolder.revealSecret(secretId, "This is a test", abi.encodePacked(bob_r, bob_s, bob_v));
    }
}
