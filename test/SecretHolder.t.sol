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
        vm.chainId(84532);
        deployCodeTo("SecretHolder.sol", 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
        secretHolder = SecretHolder(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
        (alice, alice_pk) = makeAddrAndKey("alice");
        (bob, bob_pk) = makeAddrAndKey("bob");
        (carl, carl_pk) = makeAddrAndKey("carl");
    }

    function test_commit_externalSign() public {
        bytes memory signature = hex"64e3b233579cde997a34968868880126bdfa2e14ef438d2f64d3b64f2d2b0ec40199ae0817f87532fca4e15b56af80c0692dfaa5907adbec7f07027528a314611b";
        uint256 usedSalt = 55413265760448866643891566419717387905414315466329863106176882221108994872920;
        bytes32 hash = hex"08889276974e17128a7254fa4cad40e2af7cf5e7fe6543e976a35099e7612a82";
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = signature;
        sigs[1] = signature;

        secretHolder.commitSecret(hash, usedSalt, sigs);

        uint256 id = secretHolder.secretCount() - 1;


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
        uint256 salt = 0xFFFF_FFFF;
        uint256 secretId = _commitMessage("This is a test", salt);

        bytes32 revealHash = secretHolder.buildRevealHash(secretId, "This is a test");

        // Let's have bob reveal the message
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(bob_pk, revealHash);

        vm.expectEmit(true, true, true, true);
        emit SecretHolder.SecretRevealed(secretId, bob, "This is a test");
        secretHolder.revealSecret(secretId, "This is a test", abi.encodePacked(bob_r, bob_s, bob_v));

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
        bytes32 hash = keccak256(abi.encode("This is another test", 0xFFFF_FFFF));
        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(bob_pk, hash);

        secretHolder.revealSecret(secretId, "This is another test", abi.encodePacked(bob_r, bob_s, bob_v));
    }

    function testFail_reveal_badSignature() public {
        uint256 secretId = _commitMessage("This is a test", 0xFFFF_FFFF);

        // Let's have bob sign something else entirely
        bytes32 hash = secretHolder.buildCommitHash("This is another test", 0xFFFF_FFFF);
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

        bytes32 structHash = secretHolder.buildRevealHash(secretId, "This is a test");

        (uint8 bob_v, bytes32 bob_r, bytes32 bob_s) = vm.sign(pk, structHash);

        vm.expectRevert();
        secretHolder.revealSecret(secretId, "This is a test", abi.encodePacked(bob_r, bob_s, bob_v));
    }
}
