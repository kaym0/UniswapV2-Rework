// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMana {
    function transferFrom(address from, address to, uint256 amount) external;
    function deposit(address owner, uint256 amount) external;
    function withdraw(address owner, uint256 amount) external;
}