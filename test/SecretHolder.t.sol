// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SecretHolder} from "../src/SecretHolder.sol";

contract CounterTest is Test {
    SecretHolder public secretHolder;

    /// @dev Actors
    uint256 alice_pk;
    uint256 bob_pk;
    uint256 carl_pk;


    function setUp() public {
        secretHolder = new SecretHolder();
        (, alice_pk) = makeAddrAndKey("alice");
        (, bob_pk) = makeAddrAndKey("bob");
        (, carl_pk) = makeAddrAndKey("carl");
    }

    function testFuzz_commit(uint256 salt) public {
        bytes memory message = "This is a test message";
        bytes32 hash = keccak256(abi.encode(message, salt));

        (uint8 alice_v, uint256 alice_r, uint256 alice_s) = vm.sign(alice_pk, hash);
        (uint8 bob_v, uint256 bob_r, uint256 bob_s) = vm.sign(bob_pk, hash);

        SecretHolder.Signature[] memory signatures = new SecretHolder.Signature[](2);
        signatures.push(
            SecretHolder.Signature { v: alice_v, r: alice_r, s: alice_s }
        );
        signatures.push(
            SecretHolder.Signature { v: bob_v, r: bob_r, s: bob_s }
        );

        secretHolder.commitSecret(
            hash,
            salt,
            signatures
        );
    }

}
