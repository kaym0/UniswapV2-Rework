// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IWETH {
    function deposit() external payable;

    function transfer(address dst, uint wad) external returns (bool);

    function withdraw(uint) external;

    function transferFrom(address src, address dst, uint wad) external returns (bool);

    receive() external payable;
}