// SPDX-License-Identifier: Copyright 2022
pragma solidity ^0.8.13;

import "./token/ERC20/ERC20.sol";
import "./token/ERC20/IERC20.sol";
import "./utils/Math.sol";
import "./interface/IVSwapFactory.sol";
import "./interface/IVSwapFlashee.sol";

contract VSwapPair is ERC20 {

    using Math for uint256;
    IERC20 public token0;
    IERC20 public token1;

    string public override name;
    string public override symbol = "CLP";
    uint8 public override decimals;

    IVSwapFactory factory;

    uint256 internal _reserve0;
    uint256 internal _reserve1;
    uint private unlocked;

    bool initialized;

    event Mint(address indexed to, uint amount0, uint amount1);
    event Burn(address indexed from, uint amount0, uint amount1);
    event Swap(address indexed from, uint amountOut0, uint amountOut1, uint amountIn0, uint amountIn1, address indexed to);

    error InsufficientAmount(string error);
    error InsufficientLiquidity(string error);
    error InvalidRecipient(string error);

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
        factory = IVSwapFactory(_factory);
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

    function name1() public view returns (string memory) {
        return token1.name();
    }

    function symbol0() public view returns (string memory) {
        return token0.symbol();
    }

    function symbol1() public view returns (string memory) {
        return token1.symbol();
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

    function _update(uint balance0, uint balance1, uint256 reserve0, uint256 reserve1) private {
        
    }

    /**
     *  @dev Flashes token to user without the need for an upfront payment. This is the primary mechanism by which
     *  the VSwap router exchanges tokens during a swap. This can also be used to execute flashswaps.

     *  Requirements:
     *  - Both amount0 and amount1 cannot be equal to 0
     *  - Flashed amounts cannot exceed reserves
     *  - Cannot flash tokens to respective token contracts
     *
     *  @param amountOut0 - The amount of token0 to flash
     *  @param amountOut1 - The amount of token1 to flash
     *  @param to - The recipient address of flashed tokens
     *  @param data - An abi-encoded execution call
     */
    function flash(uint256 amountOut0, uint256 amountOut1, address to, bytes memory data) external lock returns (uint256) {
        if (amountOut0 == 0 && amountOut1 == 0) revert InsufficientAmount("Cannot flash zero");
        (uint256 reserve0, uint256 reserve1) =  getReserves();
        if (amountOut0 > reserve0 || amountOut1 > reserve1) revert InsufficientLiquidity("Insufficient Liquidity");

        uint balance0;
        uint balance1;

        {
            address _token0 = address(token0);
            address _token1 = address(token1);
            if (to == _token0 && to == _token1) revert InvalidRecipient("Invalid Recipient");
            if (amountOut0 > 0) token0.transferFrom(address(this), to, amountOut0);
            if (amountOut1 > 0) token1.transferFrom(address(this), to, amountOut1);
            if (data.length > 0) IVSwapFlashee(to).flashCallback(_msgSender(), amountOut0, amountOut1, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }

        uint amountIn0 = balance0 > _reserve0 - amountOut0 ? balance0 - (_reserve0 - amountOut0) : 0;
        uint amountIn1 = balance1 > _reserve1 - amountOut1 ? balance1 - (_reserve1 - amountOut1) : 0;

        require(amountIn0 > 0 || amountIn1 > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');

        uint balance0Adjusted = (balance0 * 1000) - (amountIn0 * 3);
        uint balance1Adjusted = (balance1 * 1000) - (amountIn1 * 3);

        require(balance0Adjusted * (balance1Adjusted) >= uint(_reserve0) * (_reserve1) * (1000**2), 'UniswapV2: K');

        _update(balance0, balance1, reserve0, reserve1);
        emit Swap(_msgSender(), amountIn0, amountIn1, amountOut0, amountOut1, to);
    }
}
