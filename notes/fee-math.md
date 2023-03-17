# Fee math

When a user swaps tokens, they are subject to a fee of 0.3%.
This fee actually breaks down to two - a 0.25% fee that liquidity providers collect on swaps, and a 0.05% fee that the protocol collects.
(In other words, the protocol fee is ${1 \over 6}$ of the total fee)

For gas efficiency purposes, the protocol fee is actually collected lazily.
The total fees are collected during the swap by reducing the output amount, retaining the difference within the pool.
This increases the amount of tokens that the liquidity token has a proportional claim to.

Before mint or burn operations are processed, the contract first handles splitting the protocol fee out.
It does this by minting an appropriate amount of new liquidity tokens to the protocol address, thus transferring ownership of a fraction of tokenA and tokenB to it.

We evaluate relative liquidity value as $\sqrt{K}$:

```math
\sqrt{K} = \sqrt{A \cdot B}
```
($K$ itself is the product of the virtual active liquidity balances $A$ and $B$)

Let $K_S$ be the value of $K$ at the last time the protocol fee was computed, and $K_E$ be the value of $K$ at the time of the current protocol fee computation.

The total fees $f_{total}$ equal the growth in $\sqrt{K}$:

```math
f_{total} = {\sqrt{K_E} - \sqrt{K_S} \over \sqrt{K_E}}
```

Protocol fee $f_{protocol}$ equals a proportion $s$ of the total fees, which are in turn the growth in $K$

```math
f_{protocol} = s \cdot f_{total}
```
(As described above, $s = {1 \over 6}$)

Let $L_{protocol}$ be the number of new liquidity tokens we mint to the protocol, and $L_{total}$ be the total number of liquidity tokens when we started the current protocol fee computation.
The growth in liquidity tokens matches the protocol fees, in turn matching the fraction of relative liquidity value growth that the protocol takes.

```math
{L_{protocol} \over L_{protocol} + L_{total}} = f_{protocol}
```

Thus:

```math
{L_{protocol} \over L_{protocol} + L_{total}} = s \cdot f_{total}
```
```math
L_{protocol} = s \cdot f_{total} \cdot (L_{protocol} + L_{total})
```
```math
L_{protocol} = s \cdot f_{total} \cdot L_{protocol} + s \cdot f_{total} \cdot L_{total}
```
```math
L_{protocol} - s \cdot f_{total} \cdot L_{protocol} = s \cdot f_{total} \cdot L_{total}
```
```math
(1 - s \cdot f_{total}) \cdot L_{protocol} = s \cdot f_{total} \cdot L_{total}
```
```math
L_{protocol} = L_{total} \cdot {s \cdot f_{total} \over 1 - s \cdot f_{total}}
```
```math
L_{protocol} = L_{total} \cdot {f_{total} \over {1 \over s} - f_{total}}
```
```math
L_{protocol} = L_{total} \cdot {{\sqrt{K_E} - \sqrt{K_S} \over \sqrt{K_E}} \over {1 \over s} - {\sqrt{K_E} - \sqrt{K_S} \over \sqrt{K_E}}}
```
```math
L_{protocol} = L_{total} \cdot {\sqrt{K_E} - \sqrt{K_S} \over \sqrt{K_E} \cdot {1 \over s} - (\sqrt{K_E} - \sqrt{K_S})}
```
```math
L_{protocol} = L_{total} \cdot {\sqrt{K_E} - \sqrt{K_S} \over \sqrt{K_E} \cdot {1 \over s} - \sqrt{K_E} + \sqrt{K_S}}
```
```math
L_{protocol} = L_{total} \cdot {\sqrt{K_E} - \sqrt{K_S} \over ({1 \over s} - 1) \cdot \sqrt{K_E} + \sqrt{K_S}}
```

We know that $s = {1 \over 6}$, so:

```math
L_{protocol} = L_{total} \cdot {\sqrt{K_E} - \sqrt{K_S} \over ({1 \over {1 \over 6}} - 1) \cdot \sqrt{K_E} + \sqrt{K_S}}
```
```math
L_{protocol} = L_{total} \cdot {\sqrt{K_E} - \sqrt{K_S} \over 5 \cdot \sqrt{K_E} + \sqrt{K_S}}
```
