// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IButtonswapFactory} from "../../src/interfaces/IButtonswapFactory/IButtonswapFactory.sol";
import {IButtonswapPair} from "../../src/interfaces/IButtonswapPair/IButtonswapPair.sol";
import {ButtonswapPair2} from "../../src/ButtonswapPair2.sol";

contract MockButtonswapFactory is IButtonswapFactory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // Don't sort tokenA and tokenB, this reduces the complexity of ButtonswapPair unit tests
        bytes memory bytecode = type(ButtonswapPair2).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(tokenA, tokenB));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IButtonswapPair(pair).initialize(tokenA, tokenB);
    }

    function setFeeTo(address _feeTo) external {
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        feeToSetter = _feeToSetter;
    }
}
