// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDreamSwapFlashee {
    function flashCallback(address caller, uint256 amount0Out, uint256 amount1Out, bytes calldata data) external;
}