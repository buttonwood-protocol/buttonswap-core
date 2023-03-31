// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IButtonswapPair} from "./interfaces/IButtonswapPair/IButtonswapPair.sol";
import {ButtonswapERC20} from "./ButtonswapERC20.sol";
import {Math} from "./libraries/Math.sol";
import {PairMath} from "./libraries/PairMath.sol";
import {UQ112x112} from "./libraries/UQ112x112.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IButtonswapFactory} from "./interfaces/IButtonswapFactory/IButtonswapFactory.sol";
import {IButtonswapCallee} from "./interfaces/IButtonswapCallee.sol";

import {IButtonswapPairErrors} from "./interfaces/IButtonswapPair/IButtonswapPairErrors.sol";
import {IButtonswapPairEvents} from "./interfaces/IButtonswapPair/IButtonswapPairEvents.sol";
import {IButtonswapERC20} from "./interfaces/IButtonswapERC20/IButtonswapERC20.sol";

contract ButtonswapPair is IButtonswapPairErrors, IButtonswapPairEvents, IButtonswapERC20, ButtonswapERC20 {
    using UQ112x112 for uint224;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    address public factory;
    address public token0;
    address public token1;

    uint112 private active0Last;
    uint112 private active1Last;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    uint256 private unlocked = 1;

    modifier lock() {
        if (unlocked == 0) {
            revert Locked();
        }
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        // sufficient check
        if (msg.sender != factory) {
            revert Forbidden();
        }
        token0 = _token0;
        token1 = _token1;
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint256 active0, uint256 active1, uint256 active0New, uint256 active1New) private {
        address feeTo = IButtonswapFactory(factory).feeTo();
        if (feeTo != address(0)) {
            uint256 liquidityOut =
                PairMath.getProtocolFeeLiquidityMinted(totalSupply, active0 * active1, active0New * active1New);
            if (liquidityOut > 0) {
                _mint(feeTo, liquidityOut);
            }
        }
    }

    function _updatePriceCumulative(uint256 active0, uint256 active1) private {
        uint112 _active0 = uint112(active0);
        uint112 _active1 = uint112(active1);
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;
        unchecked {
            // overflow is desired
            timeElapsed = blockTimestamp - blockTimestampLast;
        }
        if (timeElapsed > 0 && active0 != 0 && active1 != 0) {
            // * never overflows, and + overflow is desired
            unchecked {
                price0CumulativeLast += uint256(UQ112x112.encode(_active1).uqdiv(_active0)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(_active0).uqdiv(_active1)) * timeElapsed;
            }
        }
        blockTimestampLast = blockTimestamp;
    }

    function _getDelta(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return a - b;
        }
        return b - a;
    }

    function _closestBound(uint256 activeALower, uint256 activeB, uint256 _lastActiveA, uint256 _lastActiveB)
        internal
        pure
        returns (uint256)
    {
        uint256 activeANewUpper = activeALower + 1;
        // Our activeANew is rounded, so we want to find which integer bound is closest to the ideal fractional value
        // activeANew/activeB == _lastActiveA/_lastActiveB => activeANew * _lastActiveB == _lastActiveA * activeB
        // activeB is fixed, so we can compare deltas between the two sides across each bound
        // The lowest delta represents the bound that is closest
        uint256 targetProduct = _lastActiveA * activeB;
        uint256 lowerDelta = _getDelta(activeALower * _lastActiveB, targetProduct);
        uint256 upperDelta = _getDelta(activeANewUpper * _lastActiveB, targetProduct);
        if (lowerDelta < upperDelta) {
            return activeALower;
        }
        return activeANewUpper;
    }

    function _getLiquidityBalances(uint256 total0, uint256 total1)
        internal
        view
        returns (uint256 active0, uint256 active1, uint256 inactive0, uint256 inactive1)
    {
        uint256 _active0Last = uint256(active0Last);
        uint256 _active1Last = uint256(active1Last);

        // Try it one way
        active0 = total0;
        inactive0 = 0;
        // active0Last/active1Last == active0/active1 => active1 == (active0*active1Last)/active0Last
        // active1Last/active0Last == active1/active0 => active1 == (active0*active1Last)/active0Last
        active1 = (active0 * _active1Last) / _active0Last;
        active1 = _closestBound(active1, active0, _active1Last, _active0Last);
        if (active1 <= total1) {
            inactive1 = total1 - active1;
        } else {
            // Try the other way
            active1 = total1;
            inactive1 = 0;
            // active0Last/active1Last == active0/active1 => active0 == (active1*active0Last)/active1Last
            // active1Last/active0Last == active1/active0 => active0 == (active1*active0Last)/active1Last
            active0 = (active1 * _active0Last) / _active1Last;
            active0 = _closestBound(active0, active1, _active0Last, _active1Last);
            inactive0 = total0 - active0;
        }
        // TODO could scale active to fit instead, transferring excess to inactive?
        if (active0 > type(uint112).max || active1 > type(uint112).max) {
            revert Overflow();
        }
    }

    function mint(uint256 amountIn0, uint256 amountIn1, address to) external lock returns (uint256 liquidityOut) {
        uint256 _totalSupply = totalSupply;
        address _token0 = token0;
        address _token1 = token1;
        uint256 total0 = IERC20(_token0).balanceOf(address(this));
        uint256 total1 = IERC20(_token1).balanceOf(address(this));
        // Determine current active liquidity
        (uint256 active0, uint256 active1, uint256 inactive0, uint256 inactive1) = _getLiquidityBalances(total0, total1);
        SafeERC20.safeTransferFrom(IERC20(_token0), msg.sender, address(this), amountIn0);
        SafeERC20.safeTransferFrom(IERC20(_token1), msg.sender, address(this), amountIn1);
        // Use the balance delta as input amounts to ensure feeOnTransfer or similar tokens don't disrupt Pair math
        amountIn0 = IERC20(_token0).balanceOf(address(this)) - total0;
        amountIn1 = IERC20(_token1).balanceOf(address(this)) - total1;

        if (_totalSupply == 0) {
            liquidityOut = Math.sqrt(amountIn0 * amountIn1) - MINIMUM_LIQUIDITY;
            // permanently lock the first MINIMUM_LIQUIDITY tokens
            _mint(address(0), MINIMUM_LIQUIDITY);
            // Initialize Pair last swap price
            active0Last = uint112(amountIn0);
            active1Last = uint112(amountIn1);
        } else {
            // Check that value0AddedInTermsOf1 == amountIn1 or value1AddedInTermsOf0 == amountIn0
            uint256 value0AddedInTermsOf1 = (amountIn0 * active1) / active0;
            if (value0AddedInTermsOf1 != amountIn1) {
                uint256 value1AddedInTermsOf0 = (amountIn1 * active0) / active1;
                if (value1AddedInTermsOf0 != amountIn0) {
                    revert UnequalMint();
                }
            }
            liquidityOut = PairMath.getDualSidedMintLiquidityOutAmount(
                _totalSupply, amountIn0, amountIn1, active0, active1, inactive0, inactive1
            );
        }

        if (liquidityOut == 0) {
            revert InsufficientLiquidityMinted();
        }
        _mint(to, liquidityOut);
        emit Mint(msg.sender, amountIn0, amountIn1);
    }

    function mintWithReservoir(uint256 amountIn, address to) external lock returns (uint256 liquidityOut) {
        if (amountIn == 0) {
            revert InsufficientLiquidityAdded();
        }
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            revert Uninitialized();
        }
        address _token0 = token0;
        address _token1 = token1;
        uint256 total0 = IERC20(_token0).balanceOf(address(this));
        uint256 total1 = IERC20(_token1).balanceOf(address(this));
        // Determine current active liquidity
        (uint256 active0, uint256 active1, uint256 inactive0, uint256 inactive1) = _getLiquidityBalances(total0, total1);
        if (inactive0 == 0) {
            // If inactive0 is empty then we're adding token0 to pair with token1 liquidity
            SafeERC20.safeTransferFrom(IERC20(_token0), msg.sender, address(this), amountIn);
            // Use the balance delta as input amounts to ensure feeOnTransfer or similar tokens don't disrupt Pair math
            amountIn = IERC20(_token0).balanceOf(address(this)) - total0;

            // Check there's enough inactive liquidity to pair with the amountIn
            if ((amountIn * active1) / active0 > inactive1) {
                revert InsufficientReservoir();
            }

            liquidityOut =
                PairMath.getSingleSidedMintLiquidityOutAmount(_totalSupply, amountIn, active1, active0, inactive1);
        } else {
            // If inactive1 is empty then we're adding token1 to pair with token0 liquidity
            SafeERC20.safeTransferFrom(IERC20(_token1), msg.sender, address(this), amountIn);
            // Use the balance delta as input amounts to ensure feeOnTransfer or similar tokens don't disrupt Pair math
            amountIn = IERC20(_token1).balanceOf(address(this)) - total1;

            // Check there's enough inactive liquidity to pair with the amountIn
            if ((amountIn * active0) / active1 > inactive0) {
                revert InsufficientReservoir();
            }

            liquidityOut =
                PairMath.getSingleSidedMintLiquidityOutAmount(_totalSupply, amountIn, active0, active1, inactive0);
        }

        if (liquidityOut == 0) {
            revert InsufficientLiquidityMinted();
        }
        _mint(to, liquidityOut);
        if (inactive0 == 0) {
            emit Mint(msg.sender, amountIn, 0);
        } else {
            emit Mint(msg.sender, 0, amountIn);
        }
    }

    function burn(uint256 liquidityIn, address to) external lock returns (uint256 amountOut0, uint256 amountOut1) {
        _burn(msg.sender, liquidityIn);
        uint256 _totalSupply = totalSupply;
        address _token0 = token0;
        address _token1 = token1;
        uint256 total0 = IERC20(_token0).balanceOf(address(this));
        uint256 total1 = IERC20(_token1).balanceOf(address(this));

        (amountOut0, amountOut1) = PairMath.getDualSidedBurnOutputAmounts(_totalSupply, liquidityIn, total0, total1);

        if (amountOut0 == 0 || amountOut1 == 0) {
            revert InsufficientLiquidityBurned();
        }
        SafeERC20.safeTransfer(IERC20(_token0), to, amountOut0);
        SafeERC20.safeTransfer(IERC20(_token1), to, amountOut1);
        emit Burn(msg.sender, amountOut0, amountOut1, to);
    }

    function burnFromReservoir(uint256 liquidityIn, address to)
        external
        lock
        returns (uint256 amountOut0, uint256 amountOut1)
    {
        _burn(msg.sender, liquidityIn);
        uint256 _totalSupply = totalSupply;
        address _token0 = token0;
        address _token1 = token1;
        uint256 total0 = IERC20(_token0).balanceOf(address(this));
        uint256 total1 = IERC20(_token1).balanceOf(address(this));
        // Determine current active liquidity
        (uint256 active0, uint256 active1, uint256 inactive0, uint256 inactive1) = _getLiquidityBalances(total0, total1);

        (amountOut0, amountOut1) =
            PairMath.getSingleSidedBurnOutputAmounts(_totalSupply, liquidityIn, active0, active1, inactive0, inactive1);

        if (amountOut0 > inactive0 || amountOut1 > inactive1) {
            revert InsufficientReservoir();
        }
        if (amountOut0 > 0) {
            SafeERC20.safeTransfer(IERC20(_token0), to, amountOut0);
        } else if (amountOut1 > 0) {
            SafeERC20.safeTransfer(IERC20(_token1), to, amountOut1);
        } else {
            revert InsufficientLiquidityBurned();
        }
        emit Burn(msg.sender, amountOut0, amountOut1, to);
    }

    function swap(
        uint256 amountIn0,
        uint256 amountIn1,
        uint256 amountOut0,
        uint256 amountOut1,
        address to,
        bytes calldata data
    ) external lock {
        if (amountOut0 == 0 && amountOut1 == 0) {
            revert InsufficientOutputAmount();
        }
        address _token0 = token0;
        address _token1 = token1;
        if (to == _token0 || to == _token1) {
            revert InvalidRecipient();
        }
        uint256 total0 = IERC20(_token0).balanceOf(address(this));
        uint256 total1 = IERC20(_token1).balanceOf(address(this));
        // Determine current active liquidity
        (uint256 active0, uint256 active1, uint256 inactive0, uint256 inactive1) = _getLiquidityBalances(total0, total1);
        if (amountOut0 >= active0 || amountOut1 >= active1) {
            revert InsufficientLiquidity();
        }
        if (amountIn0 > 0) {
            SafeERC20.safeTransferFrom(IERC20(_token0), msg.sender, address(this), amountIn0);
            // Use the balance delta as input amounts to ensure feeOnTransfer or similar tokens don't disrupt Pair math
            amountIn0 = IERC20(_token0).balanceOf(address(this)) - total0;
        }
        if (amountIn1 > 0) {
            SafeERC20.safeTransferFrom(IERC20(_token1), msg.sender, address(this), amountIn1);
            // Use the balance delta as input amounts to ensure feeOnTransfer or similar tokens don't disrupt Pair math
            amountIn1 = IERC20(_token1).balanceOf(address(this)) - total1;
        }
        if (amountIn0 == 0 && amountIn1 == 0) {
            revert InsufficientInputAmount();
        }
        // Optimistically transfer output
        if (amountOut0 > 0) {
            SafeERC20.safeTransfer(IERC20(_token0), to, amountOut0);
        }
        if (amountOut1 > 0) {
            SafeERC20.safeTransfer(IERC20(_token1), to, amountOut1);
        }
        if (data.length > 0) {
            IButtonswapCallee(to).buttonswapCall(msg.sender, amountOut0, amountOut1, data);
        }
        // Refresh balances
        total0 = IERC20(_token0).balanceOf(address(this));
        total1 = IERC20(_token1).balanceOf(address(this));
        (uint256 active0New, uint256 active1New, uint256 inactive0New, uint256 inactive1New) =
            _getLiquidityBalances(total0, total1);
        if (inactive0New > inactive0 || inactive1New > inactive1) {
            revert ReservoirInvariant();
        }
        uint256 active0NewAdjusted = (active0New * 1000) - (amountIn0 * 3);
        uint256 active1NewAdjusted = (active1New * 1000) - (amountIn1 * 3);
        // After account for 0.3% fees, the new K must not be less than the old K
        if (active0NewAdjusted * active1NewAdjusted < (active0 * active1 * 1000 ** 2)) {
            revert KInvariant();
        }
        _mintFee(active0, active1, active0New, active1New);
        _updatePriceCumulative(active0, active1);
        // Update Pair last swap price
        active0Last = uint112(active0New);
        active1Last = uint112(active1New);

        emit Swap(msg.sender, amountIn0, amountIn1, amountOut0, amountOut1, to);
    }
}
