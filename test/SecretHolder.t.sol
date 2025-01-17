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

    function test_commit() public {
        uint256 salt = 0;
        uint256 secretCountBefore = secretHolder.secretCount();
        bytes memory message = "This is a test message";
        bytes32 secretHash = keccak256(abi.encodePacked(message, salt));

        bytes32 structHash = secretHolder.buildCommitHash(secretHash, salt);

        bytes[] memory signatures = new bytes[](2);
        (uint8 alice_v, bytes32 alice_r, bytes32 alice_s) = vm.sign(alice_pk, structHash);
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(bob_pk, structHash);

        // NOTE: OZ's ECDSA library expects the signature to be formed this way.
        signatures[0] = abi.encodePacked(alice_r, alice_s, alice_v);
        signatures[1] = abi.encodePacked(bob_r, bob_s, bob_v);

        vm.expectEmit(false, true, true, true);
        emit SecretHolder.SecretStored(0, secretHash, alice, bob);
        secretHolder.commitSecret(secretHash, salt, signatures);

        assertEq(secretHolder.secretCount(), secretCountBefore + 1);
        
        (bytes32 commitment, address partyA, address partyB, uint256 retrieved_salt) = secretHolder.secrets(secretCountBefore);

        assertEq(commitment, secretHash);
        assertEq(partyA, alice);
        assertEq(partyB, bob);
        assertEq(retrieved_salt, salt);
    }

    function testFuzz_commit(uint256 pk_1, uint256 pk_2, uint256 salt) public {
        // NOTE: ECDSA: pk should be in this range to be a valid key
        vm.assume(pk_1 > 0);
        vm.assume(pk_1 < 115792089237316195423570985008687907852837564279074904382605163141518161494337);
        vm.assume(pk_2 > 0);
        vm.assume(pk_2 < 115792089237316195423570985008687907852837564279074904382605163141518161494337);

        bytes memory message = "This is a test message";
        bytes32 secretHash = keccak256(abi.encodePacked(message, salt));

        bytes32 structHash = secretHolder.buildCommitHash(secretHash, salt);

        bytes[] memory signatures = new bytes[](2);
        (uint8 alice_v, bytes32 alice_r, bytes32 alice_s) = vm.sign(pk_1, structHash);
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(pk_2, structHash);

        // NOTE: OZ's ECDSA library expects the signature to be formed this way.
        signatures[0] = abi.encodePacked(alice_r, alice_s, alice_v);
        signatures[1] = abi.encodePacked(bob_r, bob_s, bob_v);

        vm.expectEmit(false, true, true, true);
        emit SecretHolder.SecretStored(0, secretHash, vm.addr(pk_1), vm.addr(pk_2));
        secretHolder.commitSecret(secretHash, salt, signatures);
    }

    function _commitMessage(bytes memory message, uint256 salt) internal returns (uint256 id) {
        bytes32 secretHash = keccak256(abi.encodePacked(message, salt));
        bytes32 structHash = secretHolder.buildCommitHash(secretHash, salt);

        bytes[] memory signatures = new bytes[](2);
        (uint8 alice_v, bytes32 alice_r, bytes32 alice_s) = vm.sign(alice_pk, structHash);
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(bob_pk, structHash);

        // NOTE: OZ's ECDSA library expects the signature to be formed this way.
        signatures[0] = abi.encodePacked(alice_r, alice_s, alice_v);
        signatures[1] = abi.encodePacked(bob_r, bob_s, bob_v);

        secretHolder.commitSecret(secretHash, salt, signatures);

        id = secretHolder.secretCount() - 1;
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

    function testFail_reveal_badMessage() public {
        uint256 secretId = _commitMessage("This is a test", 0xFFFF_FFFF);

        // Let's have bob reveal a different message
        vm.prank(bob);
        secretHolder.revealSecret(secretId, "This is another test");
    }

    function testFuzz_revealed_byThirdParty(address revealer) public {
        vm.assume(revealer != alice);
        vm.assume(revealer != bob);
        uint256 secretId = _commitMessage("This is a test", 0xFFFF_FFFF);

        vm.prank(revealer);
        vm.expectRevert();
        secretHolder.revealSecret(secretId, "This is a test");
    }

    // @dev A side effect of non-reusable signatures is that the salt can't be reused
    //      for the same message
    function test_commit_cant_replay() public {
        bytes memory message = "Test";
        uint256 salt = 0xFFFFFFFF;
        _commitMessage(message, salt);

        // NOTE: Signing logic is rolled into this function since we want to knwo which call reverts
        //       and _commitMessage first calls a view function, which does not revert
        bytes32 secretHash = keccak256(abi.encodePacked(message, salt));
        bytes32 structHash = secretHolder.buildCommitHash(secretHash, salt);

        bytes[] memory signatures = new bytes[](2);
        (uint8 alice_v, bytes32 alice_r, bytes32 alice_s) = vm.sign(alice_pk, structHash);
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(bob_pk, structHash);

        // NOTE: OZ's ECDSA library expects the signature to be formed this way.
        signatures[0] = abi.encodePacked(alice_r, alice_s, alice_v);
        signatures[1] = abi.encodePacked(bob_r, bob_s, bob_v);

        vm.expectRevert();
        secretHolder.commitSecret(secretHash, salt, signatures);
    }
}
