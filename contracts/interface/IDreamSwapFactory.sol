// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDreamSwapFactory {

    function feeTo() external view returns (address);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function suffix() external view returns (string memory);
    
    function getPair(address tokenA, address tokenB) external view returns (address);
}