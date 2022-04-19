// SPDX-License-Identifier: Copyright 2022
pragma solidity ^0.8.13;

import "./interface/IVSwapPair.sol";
import "./interface/IVSwapFactory.sol";
import "./interface/IWETH.sol";
import "./libraries/VSwapLibrary.sol";
import "./libraries/TransferHelper.sol";
import "./utils/Context.sol";

contract VSwapLiquidity is Context {

    IVSwapFactory public immutable factory;
    address public immutable WETH;

    constructor(address _factory, address _WETH) {
        factory = IVSwapFactory(_factory);
        WETH = _WETH;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'VSwapLiquidity: EXPIRED');
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
        liquidity = IVSwapPair(pair).mint(to);
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        IVSwapPair pair;

        if (factory.getPair(tokenA, tokenB) == address(0)) {
            pair = IVSwapPair(factory.createPair(tokenA, tokenB));
        }

        (uint reserveA, uint reserveB) = pair.getReserves();

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = VSwapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'VSwapLiquidity: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = VSwapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'VSwapLiquidity: INSUFFICIENT_A_AMOUNT');
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
        liquidity = IVSwapPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(_msgSender(), msg.value - amountETH);
    }
}