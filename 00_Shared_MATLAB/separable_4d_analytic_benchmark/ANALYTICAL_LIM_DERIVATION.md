# Analytical LIM derivation

Let the four-dimensional state be

```text
z = (x, xdot, y, ydot),        z_e = (0, 0, -1, 0).
```

The first two coordinates follow the quadratic-cubic system and the last
two coordinates follow the bistable Duffing system. Because the equations
are uncoupled, the basin of the product equilibrium is

```text
B = B_QC x B_BD.
```

For the block Euclidean metric,

```text
||z-z_e||^2 = ||(x,xdot)-(0,0)||^2
            + ||(y,ydot)-(-1,0)||^2.
```

The boundary of the product basin is

```text
boundary(B) = (boundary(B_QC) x closure(B_BD))
              union
              (closure(B_QC) x boundary(B_BD)).
```

Moving both subsystems away from their targets cannot reduce the product
distance. Consequently,

```text
R_4D = dist(z_e,boundary(B)) = min(R_QC,R_BD).
```

For the default damping values, evaluation of Genda's analytical equations
gives

```text
alpha_QC = 0.4:  R_QC = 0.647480159700422
alpha_BD = 0.7:  R_BD = 0.728927859156115

R_4D = 0.647480159700422.
```

The active boundary component is therefore the quadratic-cubic subsystem.
One normalized four-dimensional boundary witness is approximately

```text
z_star = (0.346092703190379,
          0.547220611823008,
         -1,
          0),
```

whose Euclidean distance from `z_e` is `0.647480159700422`.

The test code recomputes both component references at run time, performs
two-resolution and integral-form consistency checks, and writes the result
to `analytical_reference.csv`. The search routines never read the reference
while selecting or classifying points; it is used only after a run to score
the estimated LIM.
