# Burn Math

The pool has two tokens that it serves as a market for, $A$ and $B$.

To handle rebasing assets, the pool keeps track of active liquidity and surplus liquidity with virtual balances.
Thus, the active $A$ liquidity $A_{pool}$ and surplus $A$ liquidity $A_{reservoir}$ sum to the total balance held by the contract $A_{total}$:

```math
A_{total} = A_{pool} + A_{reservoir}
```
(The same holds true for $B$ as well)

The pool also issues its own token to track user ownership of its liquidity, $L$.

This works via proportional redemption.
If a user's balance is $L_{user}$ and the total supply of the liquidity token is $L_{total}$ then the user has a claim to $A_{user}$ tokens:

```math
A_{user} = A_{total} \cdot {L_{user} \over L_{total}}
```

## Dual-sided Burn

As described above, the user receives $A$ and $B$ tokens proportional to the liquidity tokens they burn.

```math
A_{user} = A_{total} \cdot {L_{user} \over L_{total}}
```
```math
B_{user} = B_{total} \cdot {L_{user} \over L_{total}}
```

## Single-sided Burn

Here we allow a user to redeem their liquidity tokens for only one of $A$ or $B$, rather than a mix of both.
The output token must come from the non-zero reservoir, having equal value to the $A$ and $B$ mix that would be received from a dual-sided burn.

Assuming it is $A$'s reservoir that is non-zero, then:

```math
A_{reservoir} \gt 0
```
```math
B_{reservoir} = 0
```

We start with a dual sided burn:
```math
A_{x} = A_{total} \cdot {L_{user} \over L_{total}}
```
```math
B_{y} = B_{total} \cdot {L_{user} \over L_{total}}
```

And then swap $B_{y}$ for $A$ using the reservoir.
Let $p_{ma}$ be the moving average price of $A$ in terms of $B$.
$A_{y}$ is the $A$ tokens swapped out of the reservoir in exchange for $B_{y}$, with the swap being priced at the moving average price:
```math
A_{y} = {B_{y} \over p_{ma}}
```

The final output $A_{user}$ is the sum of these amounts:
```math
A_{user} = A_{x} + A_{y}
```

We can then substitute and rearrange to obtain a single expression for this:
```math
A_{user} = A_{x} + {B_{y} \over p_{ma}}
```
```math
A_{user} = A_{x} + {B_{total} \cdot {L_{user} \over L_{total}} \over p_{ma}}
```
```math
A_{user} = A_{total} \cdot {L_{user} \over L_{total}} + {B_{total} \cdot {L_{user} \over L_{total}} \over p_{ma}}
```
```math
A_{user} = (A_{total} + {B_{total} \over p_{ma}}) \cdot {L_{user} \over L_{total}}
```

### Validation

A key objective for the single sided operation is to ensure that reservoirs shrink or stay the same when executing the operation.
This imposes a limit on how much can be burned in this fashion.
The dual sided burn removes a proportional fraction of $A_{pool}$, $B_{pool}$, $A_{reservoir}$ and $B_{reservoir}$ (though one of the reservoirs is zero).
The removed amount for the zero reservoir token is then swapped for the other, using the reservoir to supply those tokens.

This leaves the zero reservoir pool balance identical to how it started, assuming the other token total balance hasn't reduced so much that it shrinks active liquidity.
This means that the non-zero reservoir pool balance must _also_ remain unchanged, which in turn means that all tokens being removed must sum to less than the reservoir.
```math
A_{reservoir} > 0
```
```math
B_{reservoir} = 0
```
```math
A_{user} \leq A_{reservoir}
```
