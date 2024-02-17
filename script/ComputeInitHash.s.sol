// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "buttonswap-core_forge-std/Script.sol";
import {ButtonswapPair} from "../src/ButtonswapPair.sol";

contract ComputeInitHash is Script {
    function run() external view {
        bytes32 initHashCode = keccak256(abi.encodePacked(type(ButtonswapPair).creationCode));
        console.log("The initHashCode is as follows:");
        console.logBytes32(initHashCode);
    }
}
