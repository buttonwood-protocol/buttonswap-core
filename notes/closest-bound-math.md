# Closest Bound Math

The pool has two tokens that it serves as a market for, $A$ and $B$.

Whenever there are rebases or underlying balance changes, the pair contract must keep track of the active liquidity and surplus liquidity with virtual balances in order to keep price ratio constant.

```math
\frac{A_{0}}{B_{0}} = \frac{A_{1}}{B_{1}}
``` 

If there is a change in $B$, then calculating the new $A$ is easy:

```math
A_{1} = {B_{1} \cdot \frac{A_{0}}{B_{0}}}
``` 

However, given that the pool balances are stored in integers, there will inevitably be some rounding error.
The question is thus whether to round up or down in order to minimize the error:

```math
A_{L} = \lfloor A_{1} \rfloor
``` 
```math
A_{U} = \lceil A_{1} \rceil = A_{L} + 1
``` 

This can be determined by comparing the delta of both options with that of the original price ratios, using cross multiplication.

```math
\Delta_{L} = \left| A_{L} \cdot B_{0} - A_{0} \cdot B_{1} \right|
```
```math
\Delta_{U} = \left| A_{U} \cdot B_{0} - A_{0} \cdot B_{1} \right|
```

If $\Delta_{L} < \Delta_{U}$, then round down, otherwise round up.

This math can however be simplified into a single if-condition if we examine the following properties of the values inside the absolute values.
Firstly, we're going to rewrite the deltas as follows:

```math
d_{L} = (A_{L} \cdot B_{0} - A_{0} \cdot B_{1})
```
```math
d_{U} = (A_{U} \cdot B_{0} - A_{0} \cdot B_{1})
```
```math
\Delta_{L} = \left| d_{L} \right|
```
```math
\Delta_{U} = \left| d_{U} \right|
```

The question then becomes whether $d_{L}$ or $d_{U}$ is closer to 0.
One key insight to notice is that $d_{U}$ is always strictly greater than $d_{L}$, since $A_{U} = A_{L} + 1$.

- If $d_{L}$ is positive, then $d_{U}$ must be positive and further from 0. Thus $A_{L}$ gives a smaller error.
- Likewise, if $d_{U}$ is negative, then $d_{L}$ must be negative and further from 0. Thus $A_{U}$ gives a smaller error.

It's impossible for $d_{L}$ to be positive and $d_{U}$ to be negative.
Therefore the only case that remains is when $d_{L}$ is negative and $d_{U}$ is positive.
Note that because $A_{U} = A_{L} + 1$, this means that $d_{U} = d_{L} + B_{0}$.
Thus, the bounds of $d_{U}$ and $d_{L}$ are $(-B_{0}, B_{0})$.

Note that, if $d_{U} \lt {B_{0} \over 2}$ this implies that $d_{L} \lt - {B_{0} \over 2 }$.
Thus when $d_{U} \lt {B_{0} \over 2}$, it is closer to 0 than $d_{L}$, and $A_{U}$ gives a smaller error.

With substitution and re-arrangement, we derive the condition:

```math
d_{U} \lt {B_{0} \over 2}
```
```math
A_{U} \cdot B_{0} - A_{0} \cdot B_{1} \lt {B_{0} \over 2}
```
```math
(A_{L} + 1) \cdot B_{0} - A_{0} \cdot B_{1} \lt {B_{0} \over 2}
```
```math
A_{L} \cdot B_{0} + B_{0} - {B_{0} \over 2} \lt A_{0} \cdot B_{1}
```
```math
A_{L} \cdot B_{0} + {B_{0} \over 2} \lt A_{0} \cdot B_{1}
```

## Final Function

```math
closestBound(A_{L},B_{1},A_{0},B_{0}) = \begin{cases} A_{L}+1 & A_{L} \cdot B_{0} + {B_{0} \over 2} \lt A_{0} \cdot B_{1} \\ A_{L} & \text{otherwise} \end{cases}
```

We don't need to be concerned about rounding errors caused by the division, as if it were to round up instead it takes an expression from $\text{left} \lt \text{right}$ to $\text{left} = \text{right}$ which doesn't have a "correct" outcome, as both $A_{L}$ and $A_{U}$ are equally valid.
