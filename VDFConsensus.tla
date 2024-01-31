------------ MODULE VDFConsensus ----------------

EXTENDS FiniteSets, Integers, TLC

CONSTANTS
    P \* the set of processes
,   B \* the set of malicious processes
,   tAdv \* the time it takes for a malicious process to produce a message
,   tWB \* the time it takes for a well-behaved process to produce a message

ASSUME B \subseteq P \* malicious processes are a subset of all processes
W == P \ B \* the set of well-behaved processes

Tick == Nat \* a tick is a real-time clock tick
Round == Nat \* a round is just a tag on a message

(***********************************************************************************)
(* Processes build a DAG of messages. The message-production rate of well-behaved  *)
(* processes is of 1 message per tWB ticks, and that of malicious processes is of  *)
(* 1 message per tAdv ticks. We require that, collectively, well-behaved processes *)
(* produce messages at a rate strictly higher than that of malicious processes.    *)
(***********************************************************************************)
ASSUME Cardinality(W)*tAdv > Cardinality(B)*tWB
\* TODO: I think we're going to need Cardinality(W)*tAdv > 2*Cardinality(B)*tWB

\* A message consists of a unique ID, a round number, and a coffer containing the IDs of a set of predecessor messages:
MessageID == P\times Nat
Message == [id : MessageID, round : Round, coffer : SUBSET MessageID]
sender(m) == m.id[1]

\* We will need the intersection of a set of sets:
RECURSIVE Intersection(_)
Intersection(Ss) ==
    CASE
        Ss = {} -> {}
    []  \E S \in Ss : Ss = {S} -> CHOOSE S \in Ss : Ss = {S}
    []  OTHER ->
            LET S == (CHOOSE S \in Ss : TRUE)
            IN  S \cap Intersection(Ss \ {S})

(********************************************************************************)
(* A set of messages is consistent when the intersection of the coffers of each *)
(* message is a strict majority of the coffer of each message.                  *)
(********************************************************************************)
ConsistentSet(M) ==
    LET I == Intersection({m.coffer : m \in M})
    IN \A m \in M : 2*Cardinality(I) > Cardinality(m.coffer)

(***********************************************************************************)
(* A consistent chain is a subset of the messages in the DAG that potentially has  *)
(* some dangling pointers (i.e. messages that have predecessors not in the chain)  *)
(* and that satisfies the following recursive predicate:                           *)
(*                                                                                 *)
(*     * Any set of messages which all have a round of 0 is a consistent chain.    *)
(*                                                                                 *)
(*     * A set of messages C with some non-zero rounds and maximal round r is a    *)
(*     consistent chain when, with Tip being the set of messages in the chain that *)
(*     have round r and Pred being the set of messages in the chain with round     *)
(*     r-1, Pred is a strict majority of the set of predecessors of each message   *)
(*     in Tip and C \ Tip is a consistent chain. (Note that this implies that Tip  *)
(*     is a consistent set)                                                        *)
(***********************************************************************************)
Max(X, Leq(_,_)) ==
    CHOOSE m \in X : \A x \in X : Leq(x,m)

Maximal(X, Leq(_,_)) ==
    CHOOSE m \in X : \A x \in X : \neg (Leq(m,x) /\ \neg Leq(x,m))

MaximalElements(X, Leq(_,_)) ==
    {m \in X : \A x \in X : \neg (Leq(m,x) /\ \neg Leq(x,m))}

RECURSIVE ConsistentChain(_)
ConsistentChain(M) ==
    /\  M # {}
    /\  LET r == Max({m.round : m \in M}, <=) IN
        \/  r = 0
        \/  LET Tip == { m \in M : m.round = r }
                Pred == { m \in M : m.round = r-1 }
            IN  /\  Tip # {}
                /\  \E Maj \in SUBSET Pred :
                    /\  Maj # {}
                    /\  \A m \in Tip :
                        /\ \A m2 \in Maj : m2.id \in m.coffer
                        /\  2*Cardinality(Maj) > Cardinality(m.coffer)
                /\  ConsistentChain(M \ Tip)

RECURSIVE StronglyConsistentChain(_)
StronglyConsistentChain(M) ==
    /\  M # {}
    /\  LET r == Max({m.round : m \in M}, <=) IN
        \/  r = 0
        \/  LET Tip == { m \in M : m.round = r }
                Pred == { m \in M : m.round = r-1 }
            IN  /\  Tip # {}
                /\  \A m \in Tip :
                    /\ \A m2 \in Pred : m2.id \in m.coffer
                    /\  2*Cardinality(Pred) > Cardinality(m.coffer)
                /\  StronglyConsistentChain(M \ Tip)

ConsistentChains(M) ==
    LET r == Max({m.round : m \in M}, <=)
    IN  {C \in SUBSET M : (\E m \in C : m.round = r) /\ ConsistentChain(C)}

StronglyConsistentChains(M) ==
    LET r == Max({m.round : m \in M}, <=)
    IN  {C \in SUBSET M : (\E m \in C : m.round = r) /\ StronglyConsistentChain(C)}

(***********************************************************************************)
(* Given a message DAG, the heaviest consistent chain is a consistent chain in the *)
(* DAG that has a maximal number of messages.                                      *)
(***********************************************************************************)
HeaviestConsistentChain(M) ==
    LET CCs == ConsistentChains(M)
    IN  
        IF CCs = {} THEN {}
        ELSE Max(CCs, LAMBDA C1,C2 : Cardinality(C1) <= Cardinality(C2))

HeaviestConsistentChains(M) ==
    LET CCs == ConsistentChains(M)
    IN  MaximalElements(CCs, LAMBDA C1,C2 : Cardinality(C1) <= Cardinality(C2))

HeaviestStronglyConsistentChains(M) ==
    LET SCCs == StronglyConsistentChains(M)
    IN  MaximalElements(SCCs, LAMBDA C1,C2 : Cardinality(C1) <= Cardinality(C2))

(*********************************************************************************)
(* Two chains are disjoint when there is a round smaller than their max round in *)
(* which they have no messages in common. We assume C1 and C2 have the same max  *)
(* round.                                                                        *)
(*********************************************************************************)
DisjointChains(C1,C2) ==
    LET rmax == Max({m.round : m \in C1 \cup C2}, <=)
    IN  \E r \in 0..(rmax-1) :
            {m \in C1 : m.round = r} \cap {m \in C2 : m.round = r} = {}

RECURSIVE ComponentOf(_,_)
\* The connected component of chain C amongs chains Cs
ComponentOf(C, Cs) ==
    IF \E C2 \in Cs : \neg DisjointChains(C,C2)
    THEN
        LET C2 == CHOOSE C2 \in Cs : \neg DisjointChains(C,C2)
        IN  ComponentOf(C \union C2, Cs \ {C2})
    ELSE C

RECURSIVE Components(_)
\* All the components in Cs:
Components(Cs) ==
    IF Cs = {} THEN {}
    ELSE
        LET C == CHOOSE C \in Cs : TRUE
            Comp == ComponentOf(C, Cs)
         IN  {Comp} \cup Components({C2 \in Cs : DisjointChains(C2, Comp)})

HeaviestComponent(M) ==
    LET Comps == Components(StronglyConsistentChains(M))
    IN  
        IF Comps = {} THEN {}
        ELSE Max(Comps, LAMBDA C1,C2 : Cardinality(C1) <= Cardinality(C2))

HeaviestComponents(M) ==
    LET Comps == Components(HeaviestStronglyConsistentChains(M))
    IN  
        IF Comps = {} THEN {}
        ELSE MaximalElements(Comps, LAMBDA C1,C2 : Cardinality(C1) <= Cardinality(C2))

Accepted(M) == {m \in M : \A C1,C2 \in StronglyConsistentChains(M) :
        m \in C1 /\ m \notin C2 /\ DisjointChains(C1,C2) => Cardinality(C1) >= Cardinality(C2)}

Accepted2(M) == {m \in M : \A C1 \in HeaviestConsistentChains(M) :
        \A C2 \in ConsistentChains(M) :
            m \in C1 /\ m \notin C2 /\ DisjointChains(C1,C2) => Cardinality(C1) > Cardinality(C2)}

\* M does not having dangling pointers
Complete(M) == \A m \in M : \A i \in m.coffer : \E m2 \in M : m2.id = i

(********************************)
(* Now we specify the algorithm *)
(********************************)

(*--algorithm Algo {
    variables
        messages = {};
        tick = 0;
        phase = "start"; \* each tick has two phases: "start" and "end"
        donePhase = [p \in P |-> "end"];
        pendingMessage = [p \in P |-> <<>>];
        messageCount = [p \in P |-> 0];
    define {
        currentRound == tick \div tWB \* round of well-behaved processes
        wellBehavedMessages == {m \in messages : sender(m) \in P \ B}
        \* possible sets of messages received by a well-behaved process:
        receivedMsgsSets == 
            \* ignore messages from future rounds:
            LET msgs == {m \in messages : m.round < currentRound} IN
            {M \in SUBSET msgs :
                /\  Complete(M)
                /\  wellBehavedMessages \subseteq  M}
    }
    macro sendMessage(m) {
        messages := messages \cup {m}
    }
    process (clock \in {"clock"}) {
tick:   while (TRUE) {
            await \A p \in P : donePhase[p] = phase;
            if (phase = "start")
                phase := "end"
            else {
                phase := "start";
                tick := tick+1
            }
        }
    }
    process (proc \in P \ B) \* a well-behaved process
    {
l1:     while (TRUE) {
            await phase = "start";
            if (tick % tWB = 0) {
                \* Start the VDF computation for the next message:
                with (msgs \in receivedMsgsSets)
                with (C = Accepted(msgs))
                with (predMsgs = {m \in C : m.round = currentRound-1}) {
                    pendingMessage[self] := [
                        id |-> <<self,messageCount[self]+1>>,
                        round |-> currentRound,
                        coffer |-> {m.id : m \in predMsgs}];
                    messageCount[self] := messageCount[self]+1
                }
            };
            donePhase[self] := "start";
l2:         await phase = "end";
            if (tick % tWB = tWB - 1)
                \* it's the end of the tWB period, the VDF has been computed
                sendMessage(pendingMessage[self]);
            donePhase[self] := "end";
        }
    }
    process (byz \in B) \* a malicious process
    {
lb1:    while (TRUE) {
            await phase = "start";
            if (tick % tAdv = 0) {
                \* Start the VDF computation for the next message:
                with (maxRound = Max({m.round : m \in messages} \cup {0}, <=))
                with (rnd \in {maxRound, maxRound+1})
                with (predMsgs \in SUBSET {m \in messages : m.round = rnd-1}) {
                    when rnd > 0 => predMsgs # {};
                    pendingMessage[self] := [
                        id |-> <<self,messageCount[self]+1>>,
                        round |-> rnd,
                        coffer |-> {m.id : m \in predMsgs}];
                    messageCount[self] := messageCount[self]+1
                }
            };
            donePhase[self] := "start";
lb2:        await phase = "end";
            if (tick % tAdv = tAdv - 1)
                sendMessage(pendingMessage[self]);
            donePhase[self] := "end";
        };
    }
}
*)

TypeOK == 
    /\  messages \in SUBSET Message
    /\  pendingMessage \in [P -> Message \cup {<<>>}]
    /\  tick \in Tick
    /\  phase \in {"start", "end"}
    /\  donePhase \in [P -> {"start", "end"}]
    /\  messageCount \in [P -> Nat]

messageWithID(id) == CHOOSE m \in messages : m.id = id

(**********************************************************************************)
(* The main property we want to establish is that, each round, for each message m *)
(* of a well-behaved process, the messages of well-behaved processes from the     *)
(* previous round are all in m's coffer and consist of a strict majority of m's   *)
(* coffer.                                                                        *)
(**********************************************************************************)
Safety == \A p \in P \ B : LET m == pendingMessage[p] IN
    /\  m # <<>>
    /\  m.round > 0
    =>
    /\  \A m2 \in wellBehavedMessages : m2.round = m.round-1 => m2.id \in m.coffer
    /\  LET M == {m2 \in wellBehavedMessages : m2.round = m.round-1}
        IN  2*Cardinality(M) > Cardinality(m.coffer)

\* Basic well-formedness properties:    
Inv1 == \A m \in messages : 
    /\  \A m2 \in messages : m # m2 => m.id # m2.id
    /\  \A id \in m.coffer :
        /\  \E m2 \in messages : m2.id = id
        /\  messageWithID(id).round = m.round-1
    
=================================================
