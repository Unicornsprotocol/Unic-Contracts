// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/master//contracts/math/SafeMath.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/master//contracts/GSN/Context.sol";

contract Owned is Context {
    address public _owner;
    address public _newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    modifier onlyOwner {
        require(_msgSender() == _owner,"RigelToken: Only the Owner of the contract can perform this task");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _newOwner = newOwner;
    }

    function acceptOwnership() public {
        require(_msgSender() == _newOwner,"RigelToken: Token Contract Ownership has not been set for the address");
        emit OwnershipTransferred(_owner, _newOwner);
        _owner = _newOwner;
        _newOwner = address(0);
    }
}

/**
 * @dev Implementation of the {IERC20} interface.
 *
 */
 contract RigelToken is IERC20, Owned {

    using SafeMath for uint256;
    
    mapping (address => uint256) private _balances; // Total balance per address (locked + unlocked)

    mapping (address => uint256) private _unlockedTokens; // Unlocked Tokens, available for transfer

    mapping (address => mapping (address => uint256)) private _allowances;

    struct LockRecord {
        uint256 lockingPeriod;
        uint256 tokens;
        bool isUnlocked;
    }

    mapping(address => LockRecord[]) records; // Record of Locking periods and tokens per address

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor( address owner ) public {
        _name = "RigelToken";
        _symbol = "RGP";
        _decimals = 18;
        _totalSupply = 20000000 * (10 ** 18);
        _owner = owner;
        _balances[ _owner ] = _totalSupply;
        emit Transfer( address(0), _owner, _totalSupply );
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {

        require(recipient != address(0),"RigelToken: Cannot have recipient as zero address");
        require(_balances[_msgSender()] >= amount,"RigelToken: Insufficient Balance" );
        require(_balances[recipient] + amount >= _balances[recipient],"RigelToken: Balance check failed");
        
        // update the unlocked tokens based on time
        if(_msgSender() != _owner){
            _updateUnLockedTokens(_msgSender(), amount);
            _unlockedTokens[_msgSender()] = _unlockedTokens[_msgSender()].sub(amount);
            _unlockedTokens[recipient] = _unlockedTokens[recipient].add(amount);
        }
        
        _balances[_msgSender()] = _balances[_msgSender()].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(_msgSender(),recipient,amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        
        require(spender != address(0), "RigelToken: approve to the zero address");

        _allowances[_msgSender()][spender] = amount;
        emit Approval(_msgSender(), spender, amount);

        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {

        require(recipient != address(0),"RigelToken: Cannot have recipient as zero address");
        require(sender != address(0),"RigelToken: Cannot have sender as zero address");
        require(_balances[sender] >= amount,"RigelToken: Insufficient Balance" );
        require(_balances[recipient] + amount >= _balances[recipient],"RigelToken: Balance check failed");
        require(amount <= _allowances[sender][_msgSender()],"RigelToken: Check for approved token count");
        
        // update the unlocked tokens based on time

        if(_msgSender() != _owner){
            _updateUnLockedTokens(sender, amount);
            _unlockedTokens[sender] = _unlockedTokens[sender].sub(amount);
            _unlockedTokens[recipient] = _unlockedTokens[recipient].add(amount);
        }

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        _allowances[sender][_msgSender()] = _allowances[sender][_msgSender()].sub(amount);

        emit Transfer(sender,recipient,amount);
        return true;
    }
    
     /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
     
    function burn(uint256 amount) public onlyOwner {

        require(_msgSender() != address(0), "ERC20: burn from the zero address");

        _balances[_msgSender()] = _balances[_msgSender()].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(_msgSender(), address(0), amount);
    }

    // ------------------------------------------------------------------------
    // Transfer the balance from token owner's _msgSender() to `to` _msgSender()
    // - Owner's _msgSender() must have sufficient balance to transfer
    // - 0 value transfers are allowed
    // - takes in locking Period to lock the tokens to be used
    // - if want to transfer without locking enter 0 in lockingPeriod argument 
    // ------------------------------------------------------------------------
    function distributeTokens(address to, uint tokens, uint256 lockingPeriod) onlyOwner public returns (bool success) {
        // transfer tokens to the "to" address
        transfer(to, tokens);
        // if there is no lockingPeriod, add tokens to _unlockedTokens per address
        if(lockingPeriod == 0)
            _unlockedTokens[to] = _unlockedTokens[to].add(tokens);
        // if there is a lockingPeriod, add tokens to record mapping
        else
            _addRecord(to, tokens, lockingPeriod);
        return true;
    }
        
    // ------------------------------------------------------------------------
    // Adds record of addresses with locking period and tokens to lock
    // ------------------------------------------------------------------------
    function _addRecord(address to, uint tokens, uint256 lockingPeriod) private {
        records[to].push(LockRecord(lockingPeriod,tokens, false));
    }
        
    // ------------------------------------------------------------------------
    // Checks if there is required amount of unLockedTokens available
    // ------------------------------------------------------------------------
    function _updateUnLockedTokens(address _from, uint tokens) private returns (bool success) {
        // if _unlockedTokens are greater than "tokens" of "to", initiate transfer
        if(_unlockedTokens[_from] >= tokens){
            return true;
        }
        // if _unlockedTokens are less than "tokens" of "to", update _unlockedTokens by checking record with "now" time
        else{
            _updateRecord(_from);
            // check if _unlockedTokens are greater than "token" of "to", initiate transfer
            if(_unlockedTokens[_from] >= tokens){
                return true;
            }
            // otherwise revert
            else{
                revert("RigelToken: Insufficient unlocked tokens");
            }
        }
    }
        
    // ------------------------------------------------------------------------
    // Unlocks the coins if lockingPeriod is expired
    // ------------------------------------------------------------------------
     function _updateRecord(address account) private returns (bool success){
        LockRecord[] memory tempRecords = records[account];
        uint256 unlockedTokenCount = 0;
        for(uint256 i=0; i < tempRecords.length; i++){
            if(tempRecords[i].lockingPeriod < now && tempRecords[i].isUnlocked == false){
                unlockedTokenCount = unlockedTokenCount.add(tempRecords[i].tokens);
                tempRecords[i].isUnlocked = true;
                records[account][i] = LockRecord(tempRecords[i].lockingPeriod, tempRecords[i].tokens, tempRecords[i].isUnlocked);
            }
        }
        _unlockedTokens[account] = _unlockedTokens[account].add(unlockedTokenCount);
        return true;
    }        
}
