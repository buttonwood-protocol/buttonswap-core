// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import {ButtonswapPairTest} from "./ButtonswapPair-Template.sol";
import {MockUFragments} from "buttonswap-core_mock-contracts/MockUFragments.sol";
import {ICommonMockRebasingERC20} from
    "buttonswap-core_mock-contracts/interfaces/ICommonMockRebasingERC20/ICommonMockRebasingERC20.sol";

contract ButtonswapPairMockUFragmentsTest is ButtonswapPairTest {
    function getRebasingTokenA() public override returns (ICommonMockRebasingERC20) {
        return ICommonMockRebasingERC20(address(new MockUFragments()));
    }

    function getRebasingTokenB() public override returns (ICommonMockRebasingERC20) {
        return ICommonMockRebasingERC20(address(new MockUFragments()));
    }
}
