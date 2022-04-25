// SPDX-License-Identifier: Copyright 2022
pragma solidity ^0.8.13;

import "../utils/Operator.sol";
import "../token/ERC20/AnyswapV5ERC20.sol";

contract DreamToken is AnyswapV5ERC20, Operator {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address _underlying,
        address _vault
    ) AnyswapV5ERC20 (name, symbol, decimals, address(0), _vault) {}

}