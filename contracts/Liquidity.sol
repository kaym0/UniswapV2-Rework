// SPDX-License-Identifier: Copyright
pragma solidity ^0.8.13;

import "./interface/IDreamSwapPair.sol";
import "./interface/IDreamSwapFactory.sol";
import "./interface/IWETH.sol";
import "./token/ERC20/IERC20.sol";
import "./libraries/DreamSwapLibrary.sol";
import "./libraries/TransferHelper.sol";
import "./utils/Context.sol";

contract ToknLiquidity is Context {

    IDreamSwapFactory public immutable factory;
    address payable public immutable WETH;

    constructor(address _factory, address payable _WETH) {
        factory = IDreamSwapFactory(_factory);
        WETH = _WETH;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'DreamSwapLiquidity: EXPIRED');
        _;
    }

    /**
     *
     *  @dev Adds liquidity to a pair
     *
     *  @param tokenA - The address of tokenA
     *  @param tokenB - The address of tokenB
     *
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
        address pair = DreamSwapLibrary.pairFor(address(factory), tokenA, tokenB);
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

        address pair = DreamSwapLibrary.pairFor(address(factory), token, WETH);
        
        TransferHelper.safeTransferFrom(token, _msgSender(), pair, amountToken);
        // Deposit call to WETH contract; This takes an input of ETH and wraps it, free of charge    

        IWETH(WETH).deposit{value: amountETH}();

        assert(IWETH(WETH).transfer(pair, amountETH));

        liquidity = IDreamSwapPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(_msgSender(), msg.value - amountETH);
    }

    /**
     *
     *  @dev Removes liquidity 
     *
     *
     *  @param tokenA - Address of a token to remove liquidity from
     *
     *  @param tokenB - Address of a token to remove liquidity from
     *
     *  @param liquidity - The 
     *
     *  @param amountAMin - The minimum amount of tokenA which is acceptable upon receipt.
     *
     *  @param amountBMin - The minimum amount of tokenB which is acceptable upon receipt.
     *
     *  @param to - The address to send the removed tokens to.
     *
     *  @param deadline - The time at which this transaction expires.
     *
     *
     *  @return amountA - The amount of tokenA removed
     *
     *  @return amountB - The amount of tokenB removed.
     *
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = DreamSwapLibrary.pairFor(address(factory), tokenA, tokenB);

        /// Take liquidity tokens from caller and return them to the LP
        IDreamSwapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair

        /// Burn the liquidity tokens upon receipt. This and the previous line can be reduced into a single action.
        /// The tokens don't need to be transferred before burning.
        (uint amount0, uint amount1) = IDreamSwapPair(pair).burn(to);

        (address token0,) = DreamSwapLibrary.sortTokens(tokenA, tokenB);

        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);

        require(amountA >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual returns (uint amountA, uint amountB) {
        address pair = DreamSwapLibrary.pairFor(address(factory), tokenA, tokenB);
        uint value = approveMax ? type(uint256).max : liquidity;
        IDreamSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual returns (uint amountToken, uint amountETH) {
        address pair = DreamSwapLibrary.pairFor(address(factory), token, WETH);
        uint value = approveMax ? type(uint256).max : liquidity;
        IDreamSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual returns (uint amountETH) {
        address pair = DreamSwapLibrary.pairFor(address(factory), token, WETH);
        uint value = approveMax ? type(uint256).max : liquidity;
        IDreamSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }


}