// SPDX-License-Identifer: Copyright 2022
pragma solidity ^0.8.12;

interface IVSwapV1Factory {
    function pairSuffix() external  view returns (string memory);
}