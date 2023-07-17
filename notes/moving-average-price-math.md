# Moving Average Price Math

## Variables
The movingAveragePrice (of `token0`) is implemented in the code by storing two additional variables inside each Pair:
- `uint256 internal movingAveragePrice0Last`: The previous movingAveragePrice of token0 in terms of token1 in Q112x112 format
- `uint32 internal blockTimestampLast`: The block timestamp of the last swap

And utilizing two existing pair variables:
- `uint112 internal pool0Last`: The balance of pool0 at `blockTimestampLast`
- `uint112 internal pool0Last`: The balance of pool1 at `blockTimestampLast`

All four of these values are updated on each swap.

### Q112x112 Format

Since `movingAveragePrice0Last` is in Q112x112 format, that means:
$$
\texttt{Price of token0 in terms of token1} = \frac{movingAveragePrice0Last}{2^{112}}
$$

## Behavior

Whenever interacting with the reservoir, `movingAveragePrice0()` returns the following depending on `blockTimestampLast`:
- `blockTimestampLast = block.timeStamp`: If no time has passed since the last swap (there was a previous swap in the same block), then return `movingAveragePrice0Last`
- `block.timeStamp - blockTimestampLast >= movingAverageWindow`: If no swaps have happened in the past `movingAverageWindow`, then return `pool1Last`/`pool0Last` in Q112x112 format
- Otherwise return a weighted average of of `movingAveragePrice0Last` and `pool1Last`/`pool0Last` in Q112x112 format.
