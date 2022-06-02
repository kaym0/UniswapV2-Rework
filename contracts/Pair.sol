// SPDX-License-Identifier: Copyright
pragma solidity ^0.8.13;

import "./token/ERC20/ERC20.sol";
import "./token/ERC20/IERC20.sol";
import "./interface/IDreamSwapFactory.sol";
import "./interface/IDreamSwapFlashee.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";
import "./libraries/FixedPoint.sol";

contract ToknPair is ERC20 {
    using UQ112x112 for uint224;

    /// Dreamswap Factory
    address public factory;

    /// Token addresses 
    IERC20 public token0;
    IERC20 public token1;

    /// Pair fee, this is equal to the % multiplied by 100000.
    /// Therefore, 0.3% = 30;
    uint256 public fee;

    /// Total token amounts in the pool seperated by token type.
    uint256 public balance0;
    uint256 public balance1;

    uint256 public priceLastA;
    uint256 public priceLastB;

    uint256 public kLast;

    /// Last time pair updated
    uint32 public blockTimestampLast;

    bool initialized;
    uint unlocked = 0;

    /// Errors
    error InsufficientAmount(string message);
    error InsufficientBurn(string message);
    error NoLiquidity(string message);
    error Overflow(string message);
    error InsufficientLiquidity(string message);
    error InvalidRecipient(string message);
    error KBalance(string message);


    event Swap(
        address indexed from, 
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    
    event Burn(address indexed from, uint256 amountA, uint256 amountB, address indexed to);
    event Mint(address indexed to, uint256 indexed amountA, uint256 indexed amountB);
    event Update(uint256 balance0, uint256 balance1);
 

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
        factory = _factory;
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);

        // Potential dynmically na
        
        name = string(
            abi.encodePacked(
                token0.symbol(),
                "/",
                token1.symbol(), 
                " ",
                IDreamSwapFactory(factory).suffix()
            )
        );
        

        //name = "Dream LP";
        symbol = "DSLP"; 
        decimals = 18;
        unlocked = _unlocked;
    
    }
    
    //////////////////////////////////////////
    /// Getters for pool token default values
    //////////////////////////////////////////
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

    /**
     *  @dev Gets up-to-date pool balances by querying token contracts
     *  @return balanceA - Balance of token0
     *  @return balanceB - Balance of token1
     */
    function getBalances() public view returns (uint256 balanceA, uint256 balanceB) {
        balanceA = token0.balanceOf(address(this));
        balanceB = token1.balanceOf(address(this));
    }

    /**
     *  @dev Gets current reserve balances. 
     *  @notice After adding liquidity, this is unsynced and necessary for mint functionality.
     *  The primary difference between this and getBalances() is that this returns local state variables,
     *  whereas the getBalances() function returns balances based on external token contract states.
     *
     *  @return balanceA - Balance of token0
     *  @return balanceB - Balance of token1
     */
    function getReserveBalances() public view returns (uint256 balanceA, uint256 balanceB) {
        balanceA = balance0;
        balanceB = balance1;
    }

    function mint(address to) external lock returns (uint256 assets) {
        
        /// Fetch state-level balances. After adding liquidity, these values have not yet been updated.
        (uint256 reserveA, uint256 reserveB) = getReserveBalances();

        /// Fetch balances from token contract. Aftering adding liquidity, these values have changed while
        /// balances from getReserveBalances() still reflect previous, unupdated values.
        (uint256 balanceA, uint256 balanceB) = getBalances();

        /// Subtract the old balances from new balances to see what has been gained.
        uint256 amountA = balanceA - reserveA;
        uint256 amountB = balanceB - reserveB;

        /// Current total supply.
        uint256 _totalSupply = totalSupply();


        if (_totalSupply == 0) {
            assets = Math.sqrt(amountA  * amountB);
        } else {
            assets = Math.min(
                (amountA * _totalSupply) / reserveA,
                (amountB * _totalSupply) / reserveB
            );
        }

        if (assets == 0) revert NoLiquidity("DreamSwap: No Liquidity");

        _mint(to, assets);

        _updateValues(balanceA, balanceB, reserveA, reserveB);

        emit Mint(to, amountA, amountB);

        return 0;
    }

    function burn(address to) external lock returns (uint256 amountA, uint256 amountB) {
        /// Get current local balances
        (uint256 reserveA, uint256 reserveB) = getReserveBalances();

        /// Get external balances
        (uint256 balanceA, uint256 balanceB) = getBalances();

        /// Get current LP tokens held by this contract
        uint256 liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(reserveA, reserveB);
        
        uint256 supply = totalSupply();

        amountA = (liquidity * balanceA) / supply;
        amountB = (liquidity * balanceB) / supply;

        if (amountA == 0 || amountB == 0) revert InsufficientBurn("DreamSwap: Insufficient Amount Burnt");

        _burn(address(this), liquidity);

        token0.transfer(to, amountA);
        token1.transfer(to, amountB);

        (balanceA, balanceB) = getBalances();
        _updateValues(balanceA, balanceB, reserveA, reserveB);

        if (feeOn) kLast = reserveA * reserveB; 

        emit Burn(_msgSender(), amountA, amountB, to);
    }

    function flash(uint256 amountOutA, uint256 amountOutB, address to, bytes memory data) public lock {
        if (amountOutA == 0 && amountOutB == 0) revert InsufficientAmount("DreamSwap: Cannot flash zero");

        (uint256 reserveA, uint256 reserveB) = getReserveBalances();

        if (amountOutA > balance0 || amountOutB > balance1) revert InsufficientLiquidity("DreamSwap: Insufficent Liquidity");

        uint256 balanceA;
        uint256 balanceB;

        {
            //if(to != address(token0) && to != address(token1), 'DreamSwap: INVALID_TO');    
            if(to == address(token0) || to == address(token1)) revert InvalidRecipient("Tokn: INVALID TO");
            if (amountOutA > 0) token0.transfer(to, amountOutA);
            if (amountOutB > 0) token1.transfer(to, amountOutB);
            if (data.length > 0) IDreamSwapFlashee(to).flashCallback(_msgSender(), amountOutA, amountOutB, data);
            (balanceA, balanceB) = getBalances();
        }

        /// Fetch balances post-flash
        (balanceA, balanceB) = getBalances();

        uint amountInA = balanceA > reserveA - amountOutA ? balanceA - (reserveA - amountOutA) : 0;
        uint amountInB = balanceB > reserveB - amountOutB ? balanceB - (reserveB - amountOutB) : 0;

        //require(amountInA > 0 || amountInB > 0, 'DreamSwap: INSUFFICIENT_INPUT_AMOUNT');
        if (amountInA == 0 && amountInB == 0) revert InsufficientAmount("Tokn: INSUFFICIENT AMOUNT");

        {
            uint256 balanceWithFeeA = (balanceA * 1000) - (amountInA * 3);
            uint256 balanceWithFeeB = (balanceB * 1000) - (amountInB * 3);

            if (balanceWithFeeA * balanceWithFeeB < (reserveA * reserveB) * (1000**2)) revert KBalance("DreamSwap: K");
        }
            //require(balanceWithFeeA * balanceWithFeeB >= (reserveA  * reserveB) * (1000**2), 'UniswapV2: K');

        _updateValues(balanceA, balanceB, reserveA, reserveB);

        emit Swap(_msgSender(), amountInA, amountInB, amountOutA, amountOutB, to);
    }

    function _updateValues(uint256 _balanceA, uint256 _balanceB, uint256 initialBalanceA, uint256 initialBalanceB) private {
        if (_balanceA >= type(uint256).max || _balanceB >= type(uint256).max) revert Overflow("DreamSwap: Overflow");

        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        if (timeElapsed > 0 && initialBalanceA > 0 && initialBalanceB > 0) {
            /// Stuff here
        }

        balance0 = _balanceA;
        balance1 = _balanceB;

        emit Update(balance0, balance1);
    }


    function _mintFee(uint256 _reserve0, uint256 _reserve1) private returns (bool feeOn) {
        address feeTo = IDreamSwapFactory(factory).feeTo();
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