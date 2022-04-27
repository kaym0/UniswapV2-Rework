// SPDX-License-Identifier: Copyright
pragma solidity ^0.8.13;

import "./token/ERC20/ERC20.sol";
import "./token/ERC20/IERC20.sol";
import "./interface/IManaSwapFactory.sol";
import "./interface/IManaSwapFlashee.sol";
import "./interface/IManaSwapPair.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";

contract ManaSwapPairA is ERC20, IManaSwapPair {

    using Math for uint256;
    using UQ112x112 for uint224;

    IManaSwapFactory factory;

    IERC20 public token0;
    IERC20 public token1;

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    uint112 internal reserve0;
    uint112 internal reserve1;
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint private unlocked;


    bool initialized;

    /// Errors
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

        //(address a, address b, address c, bool test, uint256 _unlocked) = abi.decode(data, (address,address,address,bool, uint256));
        
        (   address _factory,
            address _token0, 
            address _token1,
            bool _initialized,
            uint256 _unlocked
        ) = abi.decode(data, (address, address, address, bool, uint256));

        initialized = _initialized;
        factory = IManaSwapFactory(_factory);
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);

        // Potential dynmically na
        
        name = string(
            abi.encodePacked(
                token0.symbol(),
                "/",
                token1.symbol(), 
                " ",
                factory.suffix()
            )
        );
        

        //name = "Mana LP";
        symbol = "MSLP"; 
        decimals = 18;
        unlocked = _unlocked;
    
    }

    function name0() public view override returns (string memory) {
        return token0.name();
    }

    function name1() public view override returns (string memory) {
        return token1.name();
    }

    function symbol0() public view override returns (string memory) {
        return token0.symbol();
    }

    function symbol1() public view override returns (string memory) {
        return token1.symbol();
    }

    function decimals0() public view override returns (uint8) {
        return token0.decimals();
    }

    function decimals1() public view override returns (uint8) {
        return token1.decimals();
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function mint(address to) public override lock returns (uint256 assets) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); 
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;
        uint256 _totalSupply = totalSupply();

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

    function burn(address to) external override lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = address(token0);                                // gas savings
        address _token1 = address(token1);                                // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity * (balance0 / _totalSupply); // using balances ensures pro-rata distribution
        amount1 = liquidity * (balance1 / _totalSupply); // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0) * (reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     *  @dev Flashes token to user without the need for an upfront payment. This is the primary mechanism by which
     *  the ManaSwap router exchanges tokens during a swap. This can also be used to execute flashswaps.

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
    function flash(uint256 amountOut0, uint256 amountOut1, address to, bytes memory data) external override lock {
        if (amountOut0 == 0 && amountOut1 == 0) revert InsufficientAmount("Cannot flash zero");
        (uint112 _reserve0, uint112 _reserve1,) =  getReserves();
        if (amountOut0 > reserve0 || amountOut1 > reserve1) revert InsufficientLiquidity("Insufficient Liquidity");

        uint balance0;
        uint balance1;

        {
            address _token0 = address(token0);
            address _token1 = address(token1);
            if (to == _token0 && to == _token1) revert InvalidRecipient("Invalid Recipient");
            if (amountOut0 > 0) token0.transferFrom(address(this), to, amountOut0);
            if (amountOut1 > 0) token1.transferFrom(address(this), to, amountOut1);
            if (data.length > 0) IManaSwapFlashee(to).flashCallback(_msgSender(), amountOut0, amountOut1, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }

        uint amountIn0 = balance0 > _reserve0 - amountOut0 ? balance0 - (_reserve0 - amountOut0) : 0;
        uint amountIn1 = balance1 > _reserve1 - amountOut1 ? balance1 - (_reserve1 - amountOut1) : 0;

        require(amountIn0 > 0 || amountIn1 > 0, 'ManaSwapPair: INSUFFICIENT_INPUT_AMOUNT');
        {

        uint balance0Adjusted = (balance0 * 1000) - (amountIn0 * 3);
        uint balance1Adjusted = (balance1 * 1000) - (amountIn1 * 3);

        require(balance0Adjusted * (balance1Adjusted) >= uint(_reserve0) * (_reserve1) * (1000**2), 'ManaSwapPair: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(_msgSender(), amountIn0, amountIn1, amountOut0, amountOut1, to);
    }

    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'UniswapV2: OVERFLOW');

        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }

    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IManaSwapFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0) * (_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply() * (rootK - rootKLast);
                    uint denominator = (rootK * 5) + rootKLast;
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }
}
