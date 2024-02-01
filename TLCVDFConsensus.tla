----------------- MODULE TLCVDFConsensus -----------------

EXTENDS Integers, FiniteSets, TLC

CONSTANTS
    p1, p2, p3, p4, p5

P == {p1,p2,p3,p4,p5}
B == {p4,p5}
tAdv == 1
tWB == 1

\* CONSTANTS
\*   p1, p2, p3
\* P == {p1,p2,p3}
\* B == {p1}
\* tAdv == 2
\* tWB == 3

Sym == Permutations(P \ B)\cup Permutations(B)

VARIABLES messages, pendingMessage, tick, phase, donePhase, pc, messageCount

\* We replace a few definitions to make TLC faster:

RECURSIVE TLCChains(_,_)
TLCChains(M,r) ==
    LET MM == {m \in M : m.round = r} IN
        IF r = 0
        THEN {M1 : M1 \in (SUBSET MM) \ {}}
        ELSE {M1 \cup M2 : M1 \in (SUBSET MM) \ {}, M2 \in TLCChains(M \ MM, r-1)}
    
RECURSIVE TLCStronglyConsistentChains(_,_)
TLCStronglyConsistentChains(M, r) ==
    LET MM == {m \in M : m.round = r} IN
        IF r = 0
        THEN {M1 : M1 \in (SUBSET MM) \ {}}
        ELSE
            LET Candidates == {M1 \cup M2 : M1 \in (SUBSET MM) \ {}, M2 \in TLCStronglyConsistentChains(M \ MM, r-1)}
            IN {C \in Candidates :
                LET Tip == { m \in C : m.round = r }
                    Pred == { m \in C : m.round = r-1 }
                IN  /\  Tip # {}
                    /\  \A m \in Tip :
                        /\  {m2.id : m2 \in Pred} \subseteq m.coffer
                        /\  2*Cardinality(Pred) > Cardinality(m.coffer)}
    
INSTANCE VDFConsensus

\* Debugging canaries:

Canary1 == \neg (
    tick = 2 /\ phase = "end"
)

\* Check that the adversary can indeed outpace the round number of well-behaved nodes:
Canary2 == \neg (
    tick = 5 /\ \E m \in messages : m.sender = p1 /\ m.round = 2
)

\* Constraints to steer or stop the model-checker:

MaxTick == 18

TickConstraint == tick <= MaxTick

\* With this constraint we let the adversary build an initial "thin" chain of length 3:
AdvConstraint == \A m1,m2 \in messages :
    /\  sender(m1) \in B
    /\  sender(m2) \in B
    /\  m1.round <= 2
    /\  m2.round <= 2
    /\  m1.round = m2.round
    => m1 = m2

\* Examples

\* defeats MinSCCs (p4 and p5 malicious); coffer {<<p3,2>>} possible at round 2:
M1 == {
    [round |-> 0, id |-> <<p1, 1>>, coffer |-> {}],
    [round |-> 0, id |-> <<p2, 1>>, coffer |-> {}], 
    [round |-> 0, id |-> <<p3, 1>>, coffer |-> {}], 
    [round |-> 0, id |-> <<p4, 1>>, coffer |-> {}], 
    [round |-> 0, id |-> <<p5, 1>>, coffer |-> {}], 
    [round |-> 1, id |-> <<p1, 2>>, coffer |-> {<<p1, 1>>, <<p2, 1>>, <<p3, 1>>}], 
    [round |-> 1, id |-> <<p2, 2>>, coffer |-> {<<p1, 1>>, <<p2, 1>>, <<p3, 1>>}], 
    [round |-> 1, id |-> <<p3, 2>>, coffer |-> {<<p1, 1>>, <<p2, 1>>, <<p3, 1>>, <<p4, 1>>, <<p5, 1>>}],
    [round |-> 1, id |-> <<p4, 2>>, coffer |-> {<<p4, 1>>}], 
    [round |-> 1, id |-> <<p5, 2>>, coffer |-> {<<p5, 1>>}]
}

==========================================================