// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVSwapPair {
    /// Events 
    event Mint(address indexed to, uint amount0, uint amount1);
    event Burn(address indexed from, uint amount0, uint amount1);
    event Swap(address indexed to, address indexed from, uint amount0, uint amount1);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function name0() external view returns (string memory);

    function name1() external view returns (string memory);

    function decimals0() external view returns (uint8);

    function decimals1() external view returns (uint8);

    function getReserves() external view returns (uint256 reserves0, uint256 reserves1);

    function mint(address to) external returns (uint256 assets);
    
    function burn(address to) external returns (uint256 assets);

    function init(bytes memory) external;

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}