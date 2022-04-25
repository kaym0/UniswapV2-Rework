// SPDX-License-Identifier: Copyright 2022
pragma solidity ^0.8.13;

import "../utils/Operator.sol";
import "../token/ERC20/AnyswapV5ERC20.sol";

contract DreamSwapToken {

    uint256 constant MAX_SUPPLY = 1_000_000_000 ether;
    string public name = "Dream";
    string public symbol = "DREAM";
    uint8 public decimals = 18; 

    uint256 internal _totalSupply;
    uint256 public lockedSupply;

    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) public balances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed owner, uint256 value);
    event Withdraw(address indexed owner, uint256 value);

    error ZeroAddress();
    error MintExceedsMaximum();
    error InsufficientBalance();
    error InsufficientAllowance();
    error CannotBurnZeroAddressTokens();
    error MintZeroAddress();
    error MintThis();

    constructor() {
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function allowance(address from, address to) public view returns (uint256) {
        return _allowances[from][to];
    }

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    
    function totalSupply() public view returns (uint256 supply) {
        supply = lockedSupply + _totalSupply;
    }

    function approve(address to, uint256 amount) public returns (bool) {
        address from = _msgSender();
        emit Approval(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        return _transfer(_msgSender(), to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        if (allowance(from, to) < amount) revert InsufficientAllowance();
        return _transfer(from, to, amount);
    }

    function _approve(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: approve from the zero address");
        require(to != address(0), "ERC20: approve to the zero address");

        _allowances[from][to] = amount;
        emit Approval(from, to, amount);
    }

    function _spendAllowance(address from, address to, uint256 amount) internal {
        uint256 currentAllowance = _allowances[from][to];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(from, to, currentAllowance - amount);
            }
        }
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert MintZeroAddress();
        if (to == address(this)) revert MintThis();
        if (_totalSupply + amount > MAX_SUPPLY) revert MintExceedsMaximum();

        unchecked {
            _totalSupply = _totalSupply + amount;
            balances[to] = balances[to] + amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address account, uint256 amount) internal {
        if (account == address(0)) revert CannotBurnZeroAddressTokens();

        uint256 accountBalance = balances[account];
        
        if (accountBalance < amount) revert InsufficientBalance();

        unchecked {
            balances[account] = accountBalance - amount;
        }

        _totalSupply = _totalSupply - amount;

        emit Transfer(account, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balances[from] < amount) revert InsufficientBalance();

        balances[from] = balances[from] - amount;

        unchecked {
            balances[to] = balances[to] + amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }
}