-module(oracle_shares_tx).

-export([doit/3, make/4]).

%% If you bet in an oracle, and the oracle has closed, this is how
%% you get your shares out. If you bet on the winning outcome,
%% then you get positive shares. If you bet on one of the losing outcomes,
%% then you get negative shares. See docs/shared.md for more about shares.
%% The difficulty of the shares was announced when the oracle was launched.

-record(oracle_shares, {
          from,
          nonce,
          fee,
          oracle_id
         }).

make(From, Fee, OID, Trees) ->
    Accounts = trees:accounts(Trees),
    {_, Acc, Proof} = accounts:get(From, Accounts),
    Tx = #oracle_shares{
            from = From, 
            nonce = accounts:nonce(Acc) + 1, 
            fee = Fee, 
            oracle_id = OID
           },
    {Tx, [Proof]}.

doit(Tx, Trees, NewHeight) ->
    OID = Tx#oracle_shares.oracle_id,
    Oracles = trees:oracles(Trees),
    {_, Oracle, _} = oracles:get(OID, Oracles),
    Result = oracles:result(Oracle),
    false = Result == 0,
    AID = Tx#oracle_shares.from,
    Accounts = trees:accounts(Trees),
    Acc = accounts:update(AID, Trees, -Tx#oracle_shares.fee, Tx#oracle_shares.nonce, NewHeight),
    %% transform their bets into shares.
    Bets = accounts:bets(Acc),
    {_, Bet, _} = oracle_bets:get(OID, Bets),
    B2Shares = oracle_bets:to_shares(Bet, Result, NewHeight),
    Acc2 = accounts:receive_shares(Acc, B2Shares, NewHeight, Trees),
    Bets2 = oracle_bets:delete(OID, Bets),
    Acc3 = accounts:update_bets(Acc2, Bets2),
    Accounts2 = accounts:write(Accounts, Acc3),
    trees:update_accounts(Trees, Accounts2).
