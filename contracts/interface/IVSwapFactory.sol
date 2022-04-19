// SPDX-License-Identifer: Copyright 2022
pragma solidity ^0.8.0;

interface IVSwapFactory {
    function pairSuffix() external  view returns (string memory);
    function getPair(address tokenA, address tokenB) external view returns (address);
}