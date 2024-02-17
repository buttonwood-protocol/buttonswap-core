// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "buttonswap-core_forge-std/Script.sol";
import {console} from "buttonswap-core_forge-std/console.sol";

library MnemonicDerivation {
    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string constant TEST_MNEMONIC = "test test test test test test test test test test test junk";
}

contract TryDeriveKey is Script {
    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string public mnemonic;

    /// @dev The address of the transaction broadcaster.
    address public broadcaster;

    constructor() {
        mnemonic = vm.envOr({name: "MNEMONIC", defaultValue: MnemonicDerivation.TEST_MNEMONIC});
        (broadcaster,) = deriveRememberKey({mnemonic: mnemonic, index: 0});
    }
}

/// @dev From https://github.com/sablier-labs/v2-core/blob/main/script/Base.s.sol
abstract contract BaseScript is Script {
    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string internal mnemonic;

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If $ETH_FROM is defined, use it.
    /// - Otherwise, derive the broadcaster address from $MNEMONIC.
    /// - If $MNEMONIC is not defined, default to a test mnemonic.
    ///
    /// The use case for $ETH_FROM is to specify the broadcaster key and its address via the command line.
    constructor() {
        address from = vm.envOr({name: "ETH_FROM", defaultValue: address(0)});
        if (from != address(0)) {
            broadcaster = from;
        } else {
            // Forge doesn't show logs or error messages if encountering a fatal error, so we need try-catch
            try new TryDeriveKey() returns (TryDeriveKey tryDeriveKey) {
                broadcaster = tryDeriveKey.broadcaster();
                mnemonic = tryDeriveKey.mnemonic();
            } catch {
                console.log("Mnemonic is invalid.");
            }
        }
        if (keccak256(abi.encodePacked(mnemonic)) == keccak256(abi.encodePacked(MnemonicDerivation.TEST_MNEMONIC))) {
            console.log("Using test mnemonic. This is an error if ran outside of testing.");
        }
        console.log("The broadcaster address is as follows:");
        console.log(broadcaster);
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }
}
