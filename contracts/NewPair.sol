// SPDX-License-Identifier: Copyright
pragma solidity ^0.8.13;

import "./token/ERC20/ERC20.sol";
import "./token/ERC20/IERC20.sol";
import "./interface/IManaSwapFactory.sol";
import "./interface/IManaSwapFlashee.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";

contract ManaSwapPair is ERC20 {

    using Math for uint256;
    using UQ112x112 for uint224;

    /// Manaswap Factory
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

    /// Last time pair updated
    uint256 public blockTimestampLast;

    bool initialized;
    uint unlocked = 0;


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
                IManaSwapFactory(factory.suffix()
            )
        );
        

        //name = "Mana LP";
        symbol = "MSLP"; 
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
     *  @dev Gets pool balances
     */
    function getBalances() public view returns (uint256 _balance0, uint256 _balance1) {
        _balance0 = balance0;
        _balance1 = balance1;
    }

    function _fetchBalances() public view returns (uint256 balanceA, uint256 balanceB) {
        balanceA = token0.balanceOf(address(this));
        balanceB = token1.balanceOf(address(this));
    }

    function flash(uint256 amountOutA, uint256 amountOutB, address to, bytes memory data) public lock {
        if (amountOutA == 0 && amountOutB == 0) revert InsufficientAmount("DreamSwap: Cannot flash zero");
        if (amountOutA > balance0 || amountOutB > balance1) revert InsufficientLiquidity("DreamSwap: Insufficent Liquidity");

        {
            if (amountOutA > 0) token0.transfer(to, amountOutA);
            if (amountOutB > 0) token1.transfer(to, amountOutB);
            if (data.length > 0) IManaSwapFlashee(to).flashCallback(_msgSender(), amountOutA, amountOutB, data); 
        }


        uint256 balanceA

    }
}