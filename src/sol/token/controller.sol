// An implementation of ERC20 with updateable databases contracts and a proxy
// interface.
import 'auth/auth.sol';
import 'token/token.sol';
import 'token/proxy.sol';

contract DSTokenController is DSTokenProxyTarget
                            , DSAuth
{
    DSBalanceDB                public  _balances;
    DSApprovalDB               public  _approvals;
    
    // Trust calls from this address and report events here.
    DSTokenProxyEventLogger    public  _proxy;

    function DSTokenController( DSBalanceDB baldb, DSApprovalDB apprdb ) {
        _balances = baldb;
        _approvals = apprdb;
    }
    function totalSupply() constant returns (uint supply) {
        bool ok;
        (supply, ok) = _balances.getSupply();
        if( !ok ) throw;
        return supply;
    }
    function balanceOf( address who ) constant returns (uint amount) {
        bool ok;
        (amount, ok) = _balances.getBalance( who );
        if( !ok ) throw;
        return amount;
    }
    function transfer( address to, uint value) returns (bool ok) {
        ok = _balances.moveBalance( msg.sender, to, value );
        if( ok ) {
            Transfer( msg.sender, to, value );
            _proxy.eventCallback( 0, msg.sender, to, value );
        }
    }
    function transferFrom( address from, address to, uint value) returns (bool ok) {
        uint allowance;
        (allowance, ok) = _approvals.get( from, msg.sender );
        if( ok ) {
            ok = _balances.moveBalance( from, to, value);
            if( ok ) {
                Transfer( from, to, value );
                _proxy.eventCallback( 0, from, to, value );
            }
        }
    }
    function approve(address spender, uint value) returns (bool ok) {
        ok = _approvals.set( msg.sender, spender, value );
        if( ok ) {
            Approval( msg.sender, spender, value);
            _proxy.eventCallback( 1, msg.sender, spender, value );
        }
        return ok;
    }
    function allowance(address owner, address spender) constant returns (uint _allowance) {
        var (allowance, ok) = _approvals.get(owner, spender);
        if( !ok ) throw;
        return allowance;
    }

    // Proxy functions

    function transfer( address caller, address to, uint value)
             proxy_only() 
             returns (bool ok)
    {
        ok = _balances.moveBalance( caller, to, value );
        if( ok ) {
            Transfer( caller, to, value );
            _proxy.eventCallback( 0, caller, to, value );
        }
    }
    function transferFrom( address caller, address from, address to, uint value)
             proxy_only()
             returns (bool ok)
    {
        uint allowance;
        (allowance, ok) = _approvals.get( from, caller );
        if( ok && allowance > value ) {
            ok = _balances.moveBalance( from, to, value);
            if( ok ) {
                Transfer( from, to, value );
                _proxy.eventCallback( 0, from, to, value );
            }
        }
    }
    function approve( address caller, address spender, uint value)
             proxy_only()
             returns (bool ok)
    {
        ok = _approvals.set( caller, spender, value );
        if( ok ) {
            Approval( caller, spender, value);
            _proxy.eventCallback( 1, caller, spender, value );
        }
    }

    modifier proxy_only() {
        if( msg.sender == address(_proxy) ) {
            _
        }
    }
    function setProxy( DSTokenProxy proxy )
             auth()
             returns (bool ok)
    {
        _proxy = proxy;
    }
    function updateDBs( DSBalanceDB new_bal_db, address new_bal_auth, uint8 new_bal_auth_mode
                      , DSApprovalDB new_appr_db, address new_appr_auth, uint8 new_appr_auth_mode )
             auth()
             returns (bool)
    {
        var ok = _balances._ds_update_authority( new_bal_auth, new_bal_auth_mode );
        if( ok ) {
            _balances = new_bal_db;
        }
        ok = _approvals._ds_update_authority( new_appr_auth, new_appr_auth_mode );
        if( ok ) {
            _approvals = new_appr_db;
        }
        return true;
    }
}
