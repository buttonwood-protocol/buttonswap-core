# Moving Average Price Math

## Variables
The movingAveragePrice (of `token0`) is implemented in the code by storing two additional variables inside each Pair:
- `uint256 movingAveragePrice0Last`: The previous movingAveragePrice of token0 in terms of token1 in Q112x112 format
- `uint32 blockTimestampLast`: The block timestamp of the last swap

And utilizing two existing pair variables:
- `uint112 pool0Last`: The balance of pool0 at `blockTimestampLast`
- `uint112 pool1Last`: The balance of pool1 at `blockTimestampLast`

All four of these values are updated on each swap.

### Q112x112 Format

Since `movingAveragePrice0Last` is in Q112x112 format, that means:

$$
\texttt{Price of token0 in terms of token1} = \frac{movingAveragePrice0Last}{2^{112}}
$$

## Behavior

Whenever interacting with the reservoir, `movingAveragePrice0()` returns the following depending on:
- $t$: The current time
- $t_{L}$: The timestamp of the last swap
- $W$: The size of the moving average window
- $A_{L}$: The moving average price (of token0) after the last swap
- $p_{0L}$: The pool0 balance after the last swap
- $p_{1L}$: The pool1 balance after the last swap

$$
\Delta t = t - t_{L}
$$

$$
movingAveragePrice0 = \begin{cases}
A_{L} \cdot \frac{W - \Delta t}{W} + \frac{p_{0L}}{p_{1L}} \cdot \frac{\Delta t}{W} & \Delta t \le W
\\
\frac{p_{0L}}{p_{1L}} & otherwise
\end{cases}
$$
