// SPDX-License-Identifier: Copyright 2022
pragma solidity ^0.8.12;

import "./token/ERC20/ERC20.sol";
import "./token/ERC20/IERC20.sol";
import "./utils/Math.sol";
import "./interface/IVSwapV1Factory.sol";

contract VSwapV1Pair is ERC20 {

    using Math for uint256;
    IERC20 public token0;
    IERC20 public token1;

    string public override name;
    string public override symbol = "CLP";
    uint8 public override decimals;

    IVSwapV1Factory factory;

    uint256 internal _reserve0;
    uint256 internal _reserve1;
    uint private unlocked;

    bool initialized;

    event Mint(address indexed to, uint amount0, uint amount1);
    event Burn(address indexed from, uint amount0, uint amount1);
    event Swap(address indexed to, address indexed from, uint amount0, uint amount1);

    modifier lock {
        require(unlocked == 1, "LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    /// Initialize tokens
    function init(bytes memory data) public {
        require(!initialized, "Already initialized");

        (   address _factory,
            address _token0, 
            address _token1,
            bool _initialized,
            uint _unlocked
        ) = abi.decode(data, (address, address, address, bool, uint));

        initialized = initialized;
        factory = IVSwapV1Factory(_factory);
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);

        name = string(
            abi.encodePacked(
                token0.symbol(), 
                token1.symbol(), 
                factory.pairSuffix()
            )
        );

        unlocked = _unlocked;
    }

    function name0() public view returns (string memory) {
        return token0.name();
    }

    function symbol0() public view returns (string memory) {
        return token0.symbol();
    }

    function symbol1() public view returns (string memory) {
        return token1.symbol();
    }

    function name1() public view returns (string memory) {
        return token1.name();
    }

    function decimals0() public view returns (uint8) {
        return token0.decimals();
    }

    function decimals1() public view returns (uint8) {
        return token1.decimals();
    }

    function getReserves() public view returns (uint256 reserves0, uint256 reserves1) {
        reserves0 = _reserve0;
        reserves1 = _reserve1;
    }

    function mint(address to) public lock returns (uint256 assets) {
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;
        uint256 _totalSupply = totalSupply;

        if (_totalSupply == 0) {
            assets = Math.sqrt(amount0  * amount1);
        } else {
            assets = Math.min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }

        require(assets > 0, "No liquidity");

        _mint(to, assets);

        emit Mint(to, amount0, amount1);
    }

    function burn(address to) public lock returns (uint256 assets) {

    }
}
