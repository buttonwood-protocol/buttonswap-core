# Liquidity Balances Math

The pool has two tokens that it serves as a market for, $A$ and $B$.

Whenever there are rebases or underlying balance changes, the pair contract must keep track of the active liquidity and surplus liquidity with virtual balances in order to keep price ratio constant.

Denote the previous last pool balances as $A_{L}$ and $B_{L}$. Denote the total balances of the pair (active + surplus) as $A_{T}$ and $B_{T}$.

Thus, to calculate the updated pool balances there are two options for determining which token has its entire balance used in the pool and which gets a reservoir: 
- PoolA: $A_{T}$ and PoolB (surplus goes in reservoir): $A_{T} * \frac{B_{L}}{A_{L}}$
- PoolB: $B_{T}$ and PoolA (surplus goes in reservoir): $B_{T} * \frac{A_{L}}{B_{L}}$

The choice depends on whichever won't cause a PoolA to exceed $A_{T}$ and PoolB to exceed $B_{T}$.

We can thus break this down into 3 cases by looking at the balance ratios:
- $\frac{A_{T}}B_{T}} < \frac{A_{L}}B_{L}}$: Relative amount of A has decreased
- $\frac{A_{T}}B_{T}} > \frac{A_{L}}B_{L}}$: Relative amount of B has decreased
- $\frac{A_{T}}B_{T}} = \frac{A_{L}}B_{L}}$: The price ratio has not changed

What's more, is that this math can be simplified to avoid rounding-errors by using cross-multiplication:
```math
A_{T} * B_{L} ? B_{T} * A_{L}
```

## Relative amount of A has decreased
If this is the case, then that means that multiplying $A_{T}$ by the prior price ratio will result in a value that is less than $B_{T}$.
Therefore, we can use $A_{T}$ as the pool balance for A and $A_{T} * \frac{B_{L}}{A_{L}}$ as the pool balance for B.

## Relative amount of B has decreased
If this is the case, then that means that multiplying $B_{T}$ by the inverted prior price ratio will result in a value that is less than $A_{T}$.
Therefore, we can use $B_{T}$ as the pool balance for B and $B_{T} * \frac{A_{L}}{B_{L}}$ as the pool balance for A.

## The price ratio has not changed
If this is the case, then it means that either through a positive or negative rebase, the total balances are integer multiples of the prior pool balances (or vice-versa).
Thus, there are two sub-cases:
- $A_{T} = A_{L} * C$ and $B_{T} = B_{L} * C$ for some constant $C$ (scaled up)
- $A_{L} = A_{T} * C$ and $B_{L} = B_{T} * C$ for some constant $C$ (scaled down)

### Scaled Up:
If this is the case, then using either of the above methods will result in the same pool balances and no precision errors.
As an example, choosing the first method will result in the original totals (same with the latter method):
- PoolA: $A_{T} = C * A_{L}$
- PoolB: $A_{T} * \frac{B_{L}}{A_{L}} = (A_{L} * C) * \frac{B_{L}}{A_{L}} = C * B_{L} = B_{T}$

### Scaled Down:
If this is the case, then using either of the above methods will result in the same pool balances and no (additional) precision errors.
As an example, choosing the first method will result in the original totals (same with the latter method):
- PoolA: $A_{T} = A_{L} / C$ 
- PoolB: $A_{T} * \frac{B_{L}}{A_{L}} = A_{T} * \frac{B_{L}}{A_{T} * C} = B_{L} / C = B_{T}$  

## Conclusion
Thus, we can simplify the check to a single if-condition:
```math
(PoolA, PoolB) = \begin{cases} (A_{T}, A_{T} * \frac{B_{L}}{A_{L}}) & A_{T} * B_{L} \lt B_{T} * A_{L} \\ (B_{T} * \frac{A_{L}}{B_{L}}, B_{T}) & \text{otherwise} \end{cases}
```