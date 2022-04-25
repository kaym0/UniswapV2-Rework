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

    IERC20 dream;

    event Deposit(address indexed owner, uint256 indexed amountIn, uint256 indexed amountOut);
    event Withdraw(address indexed owner, uint256 indexed amountIn, uint256 indexed amountOut);

    constructor(address _dream) {
        dream = IERC20(_dream);
    }

    /**
     *  @dev Deposits Dream and receive Z
     *  @param dreamAmount - The amount of dream to deposit
     *  @return zAmount - The amount of Z minted and received 
     */
    function deposit(uint256 dreamAmount) external returns (uint256 zAmount) {
        uint256 dreamBalance = dream.balanceOf(address(this));

        if (_totalSupply == 0 || dreamBalance == 0) {
            zAmount = dreamAmount;
            _mint(_msgSender(), dreamAmount);
        } else {
            zAmount = dreamAmount * _totalSupply / dreamBalance;
            _mint(_msgSender(), zAmount);
        }

        dream.transferFrom(_msgSender(), address(this), dreamAmount);

        emit Deposit(_msgSender(), dreamAmount, zAmount);
    }

    /**
     *  @dev Withdraws Z tokens, converting to Dream
     *  @param amount - The amount of Z to use during withdraw
     *  @return dreamAmount - The amount of Dream which has been withdrawn
     */
    function withdraw(uint256 amount) public returns (uint256 dreamAmount) {
        uint256 totalZDream = totalSupply();

        dreamAmount = amount * dream.balanceOf(address(this)) / totalZDream;

        _burn(_msgSender(), amount);

        dream.transfer(_msgSender(), dreamAmount);

        emit Withdraw(_msgSender(), amount, dreamAmount);
    }

    /**
     *  @dev Fetches value of Z to Dream.
     *  @param amount - The amount of Z to get the value for.
     *  @return dreamAmount - The dream amount 
     */
    function ZForDream(uint256 amount) external view returns (uint256 dreamAmount) {
        dreamAmount = amount * (dream.balanceOf(address(this)) / _totalSupply);
    }

    /**
     *  @dev Fetches value of Dream to Z.
     *  @param dreamAmount - The amount of dream to get the value for
     *  @return zAmount - The Z amount
     */
    function DreamForZ(uint256 dreamAmount) external view returns (uint256 zAmount) {
        uint256 dreamBalance = dream.balanceOf(address(this));

        if (_totalSupply == 0 || dreamBalance == 0) {
            zAmount = dreamAmount;
        }
        else {
            zAmount = dreamAmount  * _totalSupply / dreamBalance;
        }
    }
}