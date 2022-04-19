// SPDX-License-Identifier: Copyright 2022
pragma solidity 0.8.12;

import "./VSwapToken.sol";
import "../utils/Operator.sol";
import "../token/ERC20/IERC20.sol";

contract VSwapTokenDistribution is Operator {

    IERC20 vtoken;

    constructor(address _vtoken) {
        vtoken = IERC20(_vtoken);
    }

    event Allocated(address[] indexed recipients, uint256[] indexed allocations, uint256 total);

    function disperseInitialTokens(address[] memory recipients, uint256[] memory allocations) external onlyOperator {
        uint totalAllocation;

        for (uint i; i < recipients.length; i++) {
            vtoken.transfer(recipients[i], allocations[i]);
            totalAllocation = totalAllocation + allocations[i];
        }

        emit Allocated(recipients, allocations, totalAllocation);
    }
}