----------- MODULE TLCSieve ----------------


EXTENDS Integers, FiniteSets, TLC

\* CONSTANTS
\*     p1, p2, p3, p4, p5
\* P == {p1,p2,p3,p4,p5}
\* B == {p4,p5}
\* tAdv == 1
\* tWB == 1

\* CONSTANTS
\*     p1, p2, p3, p4, p5
\* P == {p1,p2,p3,p4,p5}
\* B == {p4,p5}
\* tAdv == 3
\* tWB == 4

CONSTANTS
    p1, p2, p3
P == {p1,p2,p3}
B == {p1}
tAdv == 2
tWB == 3

VARIABLES pc, messages, tick, phase, donePhase, pendingMessage, messageCount

INSTANCE Sieve

m1 == [id |-> <<p1, 1>>, step |-> 0, coffer |-> {}]
m2 == [id |-> <<p2, 1>>, step |-> 0, coffer |-> {}]
m3 == [id |-> <<p1, 2>>, step |-> 1, coffer |-> {<<p1,1>>,<<p2,1>>}]
m4 == [id |-> <<p2, 2>>, step |-> 2, coffer |-> {<<p1,2>>}]

ASSUME ConsistentSuccessor({m1,m2}, m3)
ASSUME ConsistentDAG({m1,m2,m3})
ASSUME ConsistentDAG({m1,m2,m3,m4})
ASSUME ConsistentDAG({m3,m4})

ASSUME BootstrapSieve({m1,m2,m3,m4}) = {m4}

Sym == Permutations(P \ B) \* \cup Permutations(B)

\* Constraints to steer or stop the model-checker:
MaxTick == 8
TickConstraint == tick <= MaxTick

\* Debugging canaries:

Canary1 == \neg (
    tick = 2 /\ phase = "end"
)
\* Check that the adversary can indeed outpace the round number of well-behaved nodes:
Canary2 == \neg (
    tick = 6 /\ \E m \in messages : sender(m) = p1 /\ m.step = 2
)

M == {[id |-> <<p1, 1>>, step |-> 0, coffer |-> {}], [id |-> <<p1, 2>>, step |-> 1, coffer |-> {<<p1, 1>>}], [id |-> <<p1, 3>>, step |-> 1, coffer |-> {<<p2, 1>>}], [id |-> <<p2, 1>>, step |-> 0, coffer |-> {}], [id |-> <<p2, 2>>, step |-> 1, coffer |-> {<<p1, 1>>, <<p2, 1>>, <<p3, 1>>}], [id |-> <<p3, 1>>, step |-> 0, coffer |-> {}], [id |-> <<p3, 2>>, step |-> 1, coffer |-> {<<p2, 1>>, <<p3, 1>>}]}
ASSUME PrintT(BootstrapSieve(M))



=============================================================================