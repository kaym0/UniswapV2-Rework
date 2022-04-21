// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "../token/ERC20/ERC20.sol";
import "../token/ERC20/IERC20.sol";
import "../interface/IDream.sol";

/**
 *  @title ZZZ Token
 *  @notice This is a derivative of VToken. The primary mechanism of this token is to serve as a way to stake VToken and passively be rewarded for 
 */
contract ZToken is ERC20 {

    IDream immutable DreamSwapToken;

    uint256 public MAXIMUM_DEPOSIT = 500_000 ether;

    /// Compound rate is set to equal 100% APY
    uint256 public compoundRate = 31709791983;

    /// Compounding time is one year.
    uint256 public period = 365 days;
    uint256 public periodStart = block.timestamp;
    uint256 public periodEnd = periodStart + period;

    /// Stored deposit times
    mapping(address => uint256) public depositTime;

    event Deposit (address indexed owner, uint256 amount);
    event Withdraw (address indexed owner, uint256 amount);


    constructor(address _v) {
        DreamSwapToken = IDream(_v);
        name = "ZZZ";
        symbol = "ZZZ";
        decimals = 18;
        _mint(msg.sender, 1e30);
    }

    /**
     *  @dev Custom balanceOf function
     *  @notice Calculates and returns the balance of the owner, which  is increased over time by the compound rate.
     */
    function balanceOf(address owner) public view override returns (uint256 _balance) {
        assembly {
            let pEnd := sload(periodEnd.slot)
            let pStart := sload(periodStart.slot)
            let rate := sload(compoundRate.slot)
            let balancePosition := _balances.slot
            let multiplier

            mstore(0,owner)
            mstore(32, balancePosition)

            /// Calculate storage position for owner in mapping
            let hash := keccak256(0,64)

            /// Load owners balance from the above slot
            let rawBalance := sload(hash)

            /// Get deposit time from mapping

            let depositTimePosition := depositTime.slot
            
            /// Reuse memory
            mstore(0, owner)
            mstore(32, depositTimePosition)
            
            /// Reuse pointer for gas savings
            hash := keccak256(0, 64)

            let _depositTime := sload(hash)

            // If the timestamp is less than period end
            if lt(timestamp(), pEnd) {
                /// Multiplier is equal to ((timestamp - periodStart) * rate) + 1 ether
                multiplier := add(mul(sub(timestamp(), _depositTime), rate), 1000000000000000000)
            } 

            // The timestamp is greater than or equal to period end
            if iszero(lt(timestamp(), pEnd)) {
                /// Multiplier is equal to 2 ether (2x)
                multiplier := add(mul(sub(pEnd, _depositTime), rate), 1000000000000000000)
            }

            /// Balances is calculated with the formula [(rawBalance * multiplier) / 1 ether]
            _balance :=
                 div(mul(rawBalance, multiplier), 1000000000000000000)
        }
    }

    function rawBalanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    function totalSupply() public override view returns (uint256) {

    }

    function deposit(uint256 amount) public {
        _deposit(_msgSender(), amount);
    }

    /**
     *  @dev Deposits DreamSwap tokens into this contract. XDreamSwap tokens are then minted to the depositor in exchange.
     *  Requirements:
     *  - Depositor cannot already own tokens from this contract
     *  - Compounding cannot be over.
     *  - The maximum amount of tokens allowed for this contract cannot be exceeded upon deposit
     *
     *  @param owner - The owner of the tokens
     *  @param amount - The amount of tokens to deposit
     */
    function _deposit(address owner, uint256 amount) internal {
        require(balanceOf(owner) == 0, "XDreamSwap: Cannot deposit while still owning tokens");
        require(block.timestamp < periodEnd, "XDreamSwap: Compounding period is over");
        require(totalSupply() + amount < MAXIMUM_DEPOSIT, "XDreamSwap: Maximum Deposit Overflow");

        DreamSwapToken.transferFrom(owner, address(this), amount);

        _mint(owner, amount);

        depositTime[owner] = block.timestamp;

        emit Deposit(owner, amount);
    }

    function withdraw() public {
        _withdraw(_msgSender());
    }

    /**
     *  @dev Withdraws deposited XDreamSwap in exchange for DreamSwap tokens. If the owner is not the original depositor, no additional tokens are received.
     *  @param owner - The owner of the tokens
     *  @return amount - The amount of tokens received when withdrawing
     */
    function _withdraw(address owner) internal returns (uint256 amount) {
        uint256 rawBalance = rawBalanceOf(owner);

        if (depositTime[owner] == 0) {
            amount = rawBalance;
        } else {
            amount = balanceOf(owner);
        }

        /// Burns the raw balance of tokens
        _burn(owner, rawBalance);

        DreamSwapToken.transferFrom(address(this), owner, amount);

        emit Withdraw(owner, amount);
    }

    function _getCompoundAmount(uint256 amount) public view returns (uint256 compoundAmount) {

        bytes4 signature = bytes4(keccak256("_getCurrentRate()"));

        assembly {
            let x := mload(0x40)
            mstore(x, signature)

            let success := staticcall(
                20000,
                address(),
                0,
                x,
                0,
                x
            )

           let rate := mload(x)

            compoundAmount := div(mul(amount, x), 1000000000000000000)
        }
        /*assembly {
            let pe := sload(periodEnd.slot)
            let ps := sload(periodStart.slot)
            let rate := sload(compoundRate.slot)
            let multiplier

            if lt(timestamp(), pe) {
                multiplier := add(mul(sub(timestamp(), ps), rate), 1000000000000000000)
            } 

            if iszero(lt(timestamp(), pe)) {
                multiplier := 2000000000000000000
            }

            let a := _getCurrentRate.slot

            compoundAmount := div(mul(amount, multiplier), 1000000000000000000)
        }*/
    }

    function _getCurrentRate() public view returns (uint256 multiplier) {
        assembly {
            let pe := sload(periodEnd.slot)
            let ps := sload(periodStart.slot)
            let rate := sload(compoundRate.slot)

            if lt(timestamp(), pe) {
                multiplier := add(mul(sub(timestamp(), ps), rate), 1000000000000000000)
            } 
            
            if iszero(lt(timestamp(), pe)) {
                multiplier := 2000000000000000000
            }
        }
    }

    function calculateSomething(address test) public view returns (uint256 something) {
        assembly {
           
        }
    }
}