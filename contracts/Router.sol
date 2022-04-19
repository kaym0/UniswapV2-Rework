// SPDX-License-Identifier: Copyright 22

pragma solidity 0.8.13;

import "./interface/IVSwapFactory.sol";
import "./interface/IVSwapPair.sol";
import "./libraries/VSwapLibrary.sol";
import "./libraries/TransferHelper.sol";

contract VSwapRouter {

    IVSwapFactory factory;

    constructor(address _factory) {
        factory = IVSwapFactory(_factory);
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'VSwapRouter: EXPIRED');
        _;
    }

    function swapEthForTokens() public {}
    function swapTokensForEth() public {}

    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = VSwapLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? VSwapLibrary.pairFor(address(factory), output, path[i + 2]) : _to;

            IVSwapPair(VSwapLibrary.pairFor(address(factory), input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(  
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint256[] memory amounts) {
        amounts = VSwapLibrary.getAmountsOut(address(factory), amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'VSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, VSwapLibrary.pairFor(address(factory), path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint256[] memory amounts) {

        amounts = VSwapLibrary.getAmountsIn(address(factory), amountOut, path);
        require(amounts[0] <= amountInMax, 'VSwapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, VSwapLibrary.pairFor(address(factory), path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);

    }
}