----------------- MODULE TLCVDFConsensus -----------------

CONSTANTS
    p1, p2, p3

P == {p1,p2,p3}
B == {p1}
tAdv == 2
tWB == 3 \* the adversary has a 1.5x advantage

INSTANCE VDFConsensus

\* The TLC model-checker confirms all the assumptions below.

ASSUME Intersection({{1,2},{2,3}}) = {2}
ASSUME Intersection({}) = {}
ASSUME Intersection({{1,2},{3,4}}) = {}

m1 == [id |-> 1, round |-> 0, pred |-> {}] \* well-behaved message
m2 == [id |-> 2, round |-> 0, pred |-> {}] \* well-behaved message
m3 == [id |-> 3, round |-> 0, pred |-> {}] \* malicious message
m4 == [id |-> 4, round |-> 1, pred |-> {m1,m2}] \* well-behaved message
m5 == [id |-> 5, round |-> 1, pred |-> {m1,m2,m3}] \* well-behaved message
m6 == [id |-> 6, round |-> 1, pred |-> {m1,m3}] \* malicious message

ASSUME \neg ConsistentSet({m1,m2,m3})
ASSUME ConsistentSet({m4,m5})
ASSUME \neg ConsistentSet({m4,m5,m6})

ASSUME ConsistentChain({m1,m2,m3})
ASSUME ConsistentChain({m1,m2,m4,m5})
ASSUME \neg ConsistentChain({m1,m2,m3,m4,m5}) \* m3 is not a predecessor of m4
ASSUME \neg ConsistentChain({m1,m2,m3,m4,m5,m6}) \* {m4,m5,m6} is not even consistent

ASSUME HeaviestConsistentChain({m1,m2,m3}) = {m1,m2,m3}

(*********************************************************************************)
(* Now we have a problem: the heaviest consistent chain in {m1,m2,m3,m4,m5} does *)
(* not have all the well-behaved messages. That's because both {m1,m2,m3,m5} and *)
(* {m1,m2,m4,m5} are consistent chains, and we break ties arbitrarily. Should we *)
(* make more recent messages heavier?                                            *)
(*********************************************************************************)

ASSUME HeaviestConsistentChain({m1,m2,m3,m4,m5}) = {m1,m2,m3,m5} \* oops

==========================================================