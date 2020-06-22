variables x;
equations f;

* f..  2*x - 3 =n= 0;
f..  exp(x) =n= 0;
x.lo = -1; x.up = 1;

model lcp / f.x /;
solve lcp using mcp;
