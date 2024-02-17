// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {IBlastERC20Rebasing, YieldMode} from "../../src/interfaces/IBlastERC20Rebasing.sol";

contract MockBlastERC20Rebasing is IBlastERC20Rebasing {
    YieldMode public mockMode;

    function configure(YieldMode mode) external returns (uint256) {
        mockMode = mode;
        return 0;
    }

    function claim(address, /*recipient*/ uint256 /*amount*/ ) external pure returns (uint256) {
        return 0;
    }

    function getClaimableAmount(address /*account*/ ) external pure returns (uint256) {
        return 0;
    }
}
