// SPDX-License-Identifier: Copyright

pragma solidity 0.8.13;

import "./interface/IDreamSwapFactory.sol";
import "./interface/IDreamSwapPair.sol";
import "./interface/IWETH.sol";
import "./libraries/DreamSwapLibrary.sol";
import "./libraries/TransferHelper.sol";

contract DreamSwapRouter {

    address public immutable factory;
    address public immutable WETH;

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'DreamSwapRouter: EXPIRED');
        _;
    }

    function swapEthForTokens() public {}
    function swapTokensForEth() public {}

    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = DreamSwapLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? DreamSwapLibrary.pairFor(address(factory), output, path[i + 2]) : _to;

            IDreamSwapPair(DreamSwapLibrary.pairFor(address(factory), input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(  
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint256[] memory amounts) {
        amounts = DreamSwapLibrary.getAmountsOut(address(factory), amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'DreamSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, DreamSwapLibrary.pairFor(address(factory), path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint256[] memory amounts) {

        amounts = DreamSwapLibrary.getAmountsIn(address(factory), amountOut, path);
        require(amounts[0] <= amountInMax, 'DreamSwapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, DreamSwapLibrary.pairFor(address(factory), path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);

    }

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'DreamSwapRouter: INVALID_PATH');
        amounts = DreamSwapLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'DreamSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(DreamSwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

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

    function getAmountsIn(uint amountOut, address[] memory path) public view virtual returns (uint[] memory amounts) {
        return DreamSwapLibrary.getAmountsIn(factory, amountOut, path);
    }
}