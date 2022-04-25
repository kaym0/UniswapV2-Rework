// SPDX-License-Identifier: Copyright
pragma solidity ^0.8.13;

import "./interface/IManaSwapPair.sol";
import "./interface/IManaSwapFactory.sol";
import "./interface/IWETH.sol";
import "./libraries/ManaSwapLibrary.sol";
import "./libraries/TransferHelper.sol";
import "./utils/Context.sol";

contract ManaSwapLiquidity is Context {

    IManaSwapFactory public immutable factory;
    address public immutable WETH;

    constructor(address _factory, address _WETH) {
        factory = IManaSwapFactory(_factory);
        WETH = _WETH;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'ManaSwapLiquidity: EXPIRED');
        _;
    }

    /**
     *  @dev Adds liquidity to a pair
     *  @param tokenA - The address of tokenA
     *  @param tokenB - The address of tokenB
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = factory.getPair(tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IManaSwapPair(pair).mint(to);
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        IManaSwapPair pair;

        if (factory.getPair(tokenA, tokenB) == address(0)) {
            pair = IManaSwapPair(factory.createPair(tokenA, tokenB));
        }

        (uint reserveA, uint reserveB,) = pair.getReserves();

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = ManaSwapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'ManaSwapLiquidity: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = ManaSwapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'ManaSwapLiquidity: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );

        address pair = factory.getPair(token, WETH);
        TransferHelper.safeTransferFrom(token, _msgSender(), pair, amountToken);
        // Deposit call to WETH contract; This takes an input of ETH and wraps it, free of charge         
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IManaSwapPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(_msgSender(), msg.value - amountETH);
    }
}