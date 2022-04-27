// SPDX-License-Identifier: Copyright
pragma solidity ^0.8.13;

import "./interface/IDreamSwapPair.sol";
import "./interface/IDreamSwapFactory.sol";
import "./interface/IWETH.sol";
import "./libraries/DreamSwapLibrary.sol";
import "./libraries/TransferHelper.sol";
import "./utils/Context.sol";

contract DreamSwapLiquidity is Context {

    IDreamSwapFactory public immutable factory;
    address public immutable WETH;

    constructor(address _factory, address _WETH) {
        factory = IDreamSwapFactory(_factory);
        WETH = _WETH;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'DreamSwapLiquidity: EXPIRED');
        _;
    }

    /**
     *  @dev Adds liquidity to a pair
     *  @param tokenA - The address of tokenA
     *  @param tokenB - The address of tokenB
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = factory.getPair(tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IDreamSwapPair(pair).mint(to);
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        IDreamSwapPair pair = IDreamSwapPair(factory.getPair(tokenA, tokenB));
        
        if (address(pair) == address(0)) {
            pair = IDreamSwapPair(factory.createPair(tokenA, tokenB));
        }

        (uint256 reserveA, uint256 reserveB) = pair.getBalances();

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = DreamSwapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'DreamSwapLiquidity: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = DreamSwapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'DreamSwapLiquidity: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }

    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );

        address pair = factory.getPair(token, WETH);
        TransferHelper.safeTransferFrom(token, _msgSender(), pair, amountToken);
        // Deposit call to WETH contract; This takes an input of ETH and wraps it, free of charge         
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IDreamSwapPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(_msgSender(), msg.value - amountETH);
    }
}