// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDreamSwapFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);

    function pairSuffix() external  view returns (string memory);
    
    function getPair(address tokenA, address tokenB) external view returns (address);
}