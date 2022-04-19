// SPDX-License-Identifier: Copyright 22

pragma solidity 0.8.13;

import "./interface/IVSwapFactory.sol";
import "./interface/IVSwapPair.sol";

contract VSwapRouter {

    IVSwapFactory factory;

    constructor(address _factory) {
        factory = IVSwapFactory(_factory);
    }

    function swapEthForTokens() public {}
    function swapTokensForEth() public {}
    function swapTokensForTokens(uint256 amountIn, uint256 amountReceivedMin, address[] memory route) public {}
}