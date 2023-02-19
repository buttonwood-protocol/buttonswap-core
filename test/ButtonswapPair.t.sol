// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IButtonswapPairEvents, IButtonswapPairErrors} from "../src/interfaces/IButtonswapPair/IButtonswapPair.sol";
import {ButtonswapPair} from "../src/ButtonswapPair.sol";
import {Utils} from "./utils/Utils.sol";
import {MockERC20} from "mock-contracts/MockERC20.sol";
import {MockRebasingERC20} from "mock-contracts/MockRebasingERC20.sol";

contract ButtonswapPairTest is Test, IButtonswapPairEvents, IButtonswapPairErrors {
    MockERC20 public tokenA;
    MockRebasingERC20 public rebasingTokenA;
    MockERC20 public tokenB;
    MockRebasingERC20 public rebasingTokenB;
    address public feeToSetter;

    function setUp() public {
        tokenA = new MockERC20("TokenA","TKNA");
        rebasingTokenA = new MockRebasingERC20("TokenA","TKNA",18);
        tokenB = new MockERC20("TokenB","TKNB");
        rebasingTokenB = new MockRebasingERC20("TokenB","TKNB",18);

        feeToSetter = address(0);
    }

    function testName() public {}
}
