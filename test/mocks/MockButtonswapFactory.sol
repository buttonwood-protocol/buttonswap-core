// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {ButtonswapFactory} from "../../src/ButtonswapFactory.sol";
import {IButtonswapPair} from "../../src/interfaces/IButtonswapPair/IButtonswapPair.sol";
import {MockButtonswapPair} from "./MockButtonswapPair.sol";

contract MockButtonswapFactory is ButtonswapFactory {
    // Simplified constructor for testing
    constructor(address _permissionSetter)
        ButtonswapFactory(_permissionSetter, _permissionSetter, _permissionSetter, _permissionSetter, "Test Name", "TEST")
    {}

    function mockCreatePair(address tokenA, address tokenB) external returns (address pair) {
        // Don't sort tokenA and tokenB, this reduces the complexity of ButtonswapPair unit tests
        lastToken0 = tokenA;
        lastToken1 = tokenB;
        bytes memory bytecode = type(MockButtonswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(tokenA, tokenB));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // Resetting lastToken0/lastToken1 to 0 to refund gas
        lastToken0 = address(0);
        lastToken1 = address(0);
    }
}
