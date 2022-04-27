// SPDX-License-Identifier: Copyright

pragma solidity 0.8.13;

import "./interface/IDreamSwapFactory.sol";
import "./interface/IDreamSwapPair.sol";
import "./interface/IWETH.sol";
import "./token/ERC20/IERC20.sol";
import "./libraries/DreamSwapLibrary.sol";
import "./libraries/TransferHelper.sol";

contract DreamSwapRouter {

    address public immutable factory;
    address public immutable WETH;


    error InsufficientOutputAmount(string message);
    error ExcessiveInputAmount(string message);
    error InvalidPath(string message);

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'DreamSwapRouter: EXPIRED');
        _;
    }

    function _msgSender() private view returns (address) {
        return msg.sender;
    }

    function swapEthForTokens() public {}

    function swapTokensForEth() public {}


    /**
     *  @dev Swaps tokens by iterating through an array of addresses
     *  @param amounts - Array of amounts to swap for
     *  @param path - Array of token address. These are the tokens being swapped in order.
     *  @param _to - The address to send the resulting swapped tokens to
     */
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            /// Get token contracts via pathing
            (address input, address output) = (path[i], path[i + 1]);

            /// Get address token0
            (address token0,) = DreamSwapLibrary.sortTokens(input, output);

            /// Amount out for swap
            uint amountOut = amounts[i + 1];

            /// Get swap amounts for current iteration
            (uint amount0Out, uint amount1Out) = input == token0 
                ? (uint(0), amountOut) 
                : (amountOut, uint(0));

            address to = i < path.length - 2 ? DreamSwapLibrary.getPair(factory, output, path[i + 2]) : _to;
            //address to = i < path.length - 2 
            //    ? DreamSwapLibrary.pairFor(address(factory), output, path[i + 2]) 
            //    : _to;

            /// Execute flash/swap
            IDreamSwapPair(IDreamSwapFactory(factory).getPair(input, output)).flash(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    /**
     *  @dev Swaps an exact number of ERC20 tokens for ERC20 tokens 
     *  @param amountIn - The exact number on of input tokens
     *  @param amountOutMin - The minimum accepted output tokens for the swap to succeed
     *  @param path - The swap routing. The number of swaps executed is equal to N - 1, with a minimum length of 2.
     *  @param to - The address which the resulting tokens will be sent to.
     *  @param deadline - The time at which this swap expires. Useful for period of high gas fees or network lag to prevent trades
     *  which would execute later than they should.
     */
    function swapExactTokensForTokens(  
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint256[] memory amounts) {
        
        /// Checks amounts
        amounts = DreamSwapLibrary.getAmountsOut(address(factory), amountIn, path);

        /// Check here if the trade is possible, revert if not.
        //require(amounts[amounts.length -1] >= amountOutMin, "DreamSwap: Insufficent Output Amount");
        if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount("DreamSwap: Insufficent Output Amount");

        /// Trade looks okay. Execute transfer.

        //IERC20(path[0]).transferFrom(msg.sender, DreamSwapLibrary.getPair(address(factory), path[0], path[1]), amounts[0]);

        TransferHelper.safeTransferFrom(    
            path[0], msg.sender, DreamSwapLibrary.getPair(address(factory), path[0], path[1]), amounts[0]
        );

        /// Execute flash/swap.
        _swap(amounts, path, to);
    }

    /**
     *  @dev Swaps ERC20 tokens for an exact number of output tokens.
     *  @param amountOut - The exact number of output tokens required for the trade to succeed
     *  @param amountInMax - The maximum amount of tokens that will be used to achieve the desired output 
     *  @param path - The swap routing. The number of swaps executed is equal to N - 1, with a minimum length of 2.
     *  @param to - The address which the resulting tokens will be sent to.
     *  @param deadline - The time at which this swap expires. Useful for period of high gas fees or network lag to prevent trades
     *  which would execute later than they should.
     */
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint256[] memory amounts) {
        /// Fetch amounts
        amounts = DreamSwapLibrary.getAmountsIn(address(factory), amountOut, path);

        /// if amounts[0] is greater than amountInMax, we revert.
        require(amounts[0] <= amountInMax, "Dreamswap: Excessive Input Amount");

        if (amounts[0] > amountInMax) revert ExcessiveInputAmount("DreamSwap: Excessive Input Amount");

        /// Transfer tokens here.
        TransferHelper.safeTransferFrom(
            path[0], _msgSender(), DreamSwapLibrary.getPair(address(factory), path[0], path[1]), amounts[0]
        );

        /// Execute flash/swap.
        _swap(amounts, path, to);

    }


    /**
     *  @dev Swaps exact amount of ETH for a variable amount of ERC20 tokens with a set minimum.
     *  @param amountOutMin - The minimum amount of tokens acceptable for the swap to execute.
     *  @param path - The p
     *  @param path - The swap routing. The number of swaps executed is equal to N - 1, with a minimum length of 2.
     *  @param to - The address which the resulting tokens will be sent to.
     *  @param deadline - The time at which this swap expires. Useful for period of high gas fees or network lag to prevent trades
     *  which would execute later than they should.
     */
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        /// If the first swapped token is not ETH we revert, since this is not the correct function.
        require(path[0] == WETH, "Dreamswap: Invalid Path");
        if (path[0] != WETH) revert InvalidPath("DreamSwap: Invalid Path");

        /// Fetch amounts using input values
        amounts = DreamSwapLibrary.getAmountsOut(factory, msg.value, path);

        /// If amount is less than amountOutMin, we revert.
        require(amounts[amounts.length -1] >= amountOutMin, "DreamSwap: Insufficent Output Amount");
        if (amounts[amounts.length -1] < amountOutMin) revert InsufficientOutputAmount("DreamSwap: Insufficent Output Amount");
        
        /// Wraps ETH
        IWETH(WETH).deposit{value: amounts[0]}();

        /// Ensure that the transfer executes successfully
        assert(IWETH(WETH).transfer(DreamSwapLibrary.getPair(factory, path[0], path[1]), amounts[0]));

        /// Execute flash/swap.
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external virtual ensure(deadline) returns (uint[] memory amounts) 
    {
        require(path[path.length - 1] == WETH, 'DreamSwap: INVALID_PATH');

        amounts = DreamSwapLibrary.getAmountsIn(factory, amountOut, path);

        require(amounts[0] <= amountInMax, 'DreamSwap: EXCESSIVE_INPUT_AMOUNT');

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, DreamSwapLibrary.getPair(factory, path[0], path[1]), amounts[0]
        );
        
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }



    /**
     *  @dev Gives a quote based on input values
     *  @param amountA - The amount to swap 
     *  @param reserveA - The total reserves for tokenA.
     *  @param reserveB - The total reserves for tokenB.
     *  @return amountB - The expected output amount given the input values
     */
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual returns (uint amountB) {
        return DreamSwapLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure virtual returns (uint amountOut) {
        return DreamSwapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public pure virtual returns (uint amountIn) {
        return DreamSwapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path) public view virtual returns (uint[] memory amounts) {
        return DreamSwapLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path) public view virtual returns (uint256[] memory amounts) {
        return DreamSwapLibrary.getAmountsIn(factory, amountOut, path);
    }
}