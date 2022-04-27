// SPDX-License-Identifier: Copyright
pragma solidity ^0.8.13;

import "./token/ERC20/ERC20.sol";
import "./token/ERC20/IERC20.sol";
import "./interface/IManaSwapFactory.sol";
import "./interface/IManaSwapFlashee.sol";
import "./interface/IManaSwapPair.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";

contract ManaSwapPair is ERC20 {

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


    event Mint(address indexed to, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(address indexed from, uint amountOut0, uint amountOut1, uint amountIn0, uint amountIn1, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);

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

    function name0() public view  returns (string memory) {
        return token0.name();
    }

    function name1() public view  returns (string memory) {
        return token1.name();
    }

    function symbol0() public view  returns (string memory) {
        return token0.symbol();
    }

    function symbol1() public view  returns (string memory) {
        return token1.symbol();
    }

    function decimals0() public view  returns (uint8) {
        return token0.decimals();
    }

    function decimals1() public view  returns (uint8) {
        return token1.decimals();
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
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

        /// Update reserves
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);


        /// Set last update time
        blockTimestampLast = blockTimestamp;

        /// Emit new reserve balances
        emit Sync(reserve0, reserve1);
    }

    /**
     *  @dev Primary router functionality. This is executed by the Router during swaps.
     *  This is also used for flashloans
     *
     *  @notice This function is protected against reentrancy and therefore cannot be called more
     *  than one time during a single call.
     *
     *  @param amountOut0 -
     *  @param amountOut1 -
     *  @param to  - Address to receive funds
     *  @param data - The data to send to the flashswap callee   
     */
    function flash(uint256 amountOut0, uint256 amountOut1, address to, bytes memory data) public lock {
        if (amountOut0 == 0 && amountOut1 ==0) revert InsufficientAmount("ManaSwap: Cannot swap Zero");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();


        {
            /// Execute Flashloan or Swap
            if (amountOut0 > _reserve0 || amountOut1 > _reserve1) revert InsufficientLiquidity("ManaSwap: Insufficient Liquidity");

            /// If amount0 > 0, transfer the amount to "to" address
            if (amountOut0 > 0) _safeTransfer(address(token0), to, amountOut0);

            /// If amount1 > 0, transfer the amount to "to" address
            if (amountOut1 > 0) _safeTransfer(address(token1), to, amountOut1);

            /// If data length is greater than 0, execute flashloan callback 
            if (data.length > 0) IManaSwapFlashee(to).flashCallback(_msgSender(), amountOut0, amountOut1, data);
        }

        /// Check new balances
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        /// Adjust balances based on 0.3% fee.
        uint256 balanceAdjusted0 = (balance0 * 1000) - (amountOut1 * 3);
        uint256 balanceAdjusted1 = (balance1 * 1000) - (amountOut1 * 3);

        uint amountIn0 = balance0 > _reserve0 - amountOut0 ? balance0 - (_reserve0 - amountOut0) : 0;
        uint amountIn1 = balance1 > _reserve1 - amountOut1 ? balance1 - (_reserve1 - amountOut1) : 0;

        /// Make sure balance of pool is not disturbed 
        require(balanceAdjusted0 * (balanceAdjusted1) >= uint(_reserve0) * (_reserve1) * (1000**2), 'ManaSwapPair: K');

        /// Update reserves & last update time
        _update(balance0, balance1, _reserve0, _reserve1);
        
        /// Emit swap to chain
        emit Swap(_msgSender(), amountIn0, amountIn1, amountOut0, amountOut1, to);
    }


    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }
}
