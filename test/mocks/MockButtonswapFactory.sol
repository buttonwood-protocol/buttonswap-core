// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import {IButtonswapFactory} from "../../src/interfaces/IButtonswapFactory/IButtonswapFactory.sol";
import {IButtonswapPair} from "../../src/interfaces/IButtonswapPair/IButtonswapPair.sol";
import {MockButtonswapPair} from "./MockButtonswapPair.sol";

contract MockButtonswapFactory is IButtonswapFactory {
    address public feeTo;
    address public feeToSetter;
    bool public isCreationRestricted;
    bool public isPaused;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    address lastTokenA;
    address lastTokenB;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // Don't sort tokenA and tokenB, this reduces the complexity of ButtonswapPair unit tests
        lastTokenA = tokenA;
        lastTokenB = tokenB;
        bytes memory bytecode = type(MockButtonswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(tokenA, tokenB));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // Resetting lastTokenA/lastTokenB to 0 to refund gas
        lastTokenA = address(0);
        lastTokenB = address(0);
    }

    function setFeeTo(address _feeTo) external {
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        feeToSetter = _feeToSetter;
    }

    function setIsCreationRestricted(bool _isCreationRestricted) external {
        isCreationRestricted = _isCreationRestricted;
    }

    function setIsPaused(bool _isPaused) external {
        if (msg.sender != feeToSetter) {
            revert Forbidden();
        }
        isPaused = _isPaused;
    }

    function lastCreatedPairTokens() external view returns (address token0, address token1) {
        token0 = lastTokenA;
        token1 = lastTokenB;
    }
}
