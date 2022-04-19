// SPDX-License-Identifier: Copyright 2022
pragma solidity ^0.8.13;

import "./interface/IVSwapPair.sol";
import "./interface/IVSwapFactory.sol";

contract VSwapLiquidity {

    IVSwapFactory factory;

    constructor(address _factory) {
        factory = IVSwapFactory(_factory);
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
    ) external virtual returns (uint amountA, uint amountB, uint liquidity) {
        address pair = factory.getPair(tokenA, tokenB);
    }

}