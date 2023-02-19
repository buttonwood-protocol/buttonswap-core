// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Utils {
    function isValidPrivateKey(uint256 privateKey) internal pure returns (bool) {
        // See https://cryptobook.nakov.com/digital-signatures/ecdsa-sign-verify-messages
        if (privateKey == 0) {
            // The ECDSA docs say 0 is fine but it results in invalid private key errors so prevent it anyway
            return false;
        }
        if (privateKey >= 115792089237316195423570985008687907852837564279074904382605163141518161494337) {
            return false;
        }
        return true;
    }
}
