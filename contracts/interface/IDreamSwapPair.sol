// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDreamSwapPair {
    /// Events
    event Mint(address indexed to, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(address indexed from, uint amountOut0, uint amountOut1, uint amountIn0, uint amountIn1, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);

    function name0() external view returns (string memory);

    function name1() external view returns (string memory);

    function symbol0() external view returns (string memory);

    function symbol1() external view returns (string memory);

    function decimals0() external view returns (uint8);

    function decimals1() external view returns (uint8);

    function getBalances() external view returns (uint256 balance0, uint256 balance1);

    function getReserveBalances() external view returns (uint256 balance0, uint256 balance1);

    function mint(address to) external returns (uint256 assets);
    
    function burn(address to) external returns (uint amount0, uint amount1);

    function init(bytes memory) external;

    function flash(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(address from, address to, uint value) external returns (bool);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}