// SPDX-License-Identifier: Copyright 2022
pragma solidity ^0.8.13;

import "./interface/IManaSwapPair.sol";
import "./utils/Operator.sol";

contract ManaSwapFactory is Operator {

    string public suffix = "MLP";
    address public feeTo;

    uint256 public liquidityBaseFee = 30;

    address _implementation;

    mapping (address => mapping(address => address)) pairs;

    event NewPair (address indexed token0, address indexed token1, address indexed pair);
    event FeeChange(address indexed operator, uint256 indexed fee);

    /**
     *  @dev Creates a new pair if one does not already exist
     *  @notice Uses minimal proxy pattern and initialization in a single transaction to minimize gas fees while maxmizing functionality.
     *  @param token0 - The address of token0
     *  @param token1 - The address of token1
     *  @return pair - The new pair address
     */
    function createPair(address token0, address token1) public returns (address pair) {
        require(_checkIfPairExists(token0, token1) == address(0), "Pair already exists");
        // Create minimal proxy 
        pair = _createMinimalProxy(_implementation);

        // Encode initialization data
        bytes memory data = _encodeData(token0, token1);

        // Initialize Pair contract
        IManaSwapPair(pair).init(data);

        

        // Map pair address
        pairs[token0][token1] = pair;

        // Emit event stating new pair exists
        emit NewPair(token0, token1, pair);
    }

    /**
     *  @dev Gets the address of a pairing of token0 and token1 if it exists.
     *  @notice Tokens do not need to be in correct order for this to work
     *  @return pair - the pair address
     */
    function getPair(address token0, address token1) public view returns (address pair) {
        pair = _checkIfPairExists(token0, token1);
    }

    /**
     *  @dev Sets the implementation contract. This is the contract which is cloned as a minimal proxy.
     */
    function setImplementation(address implementation_) public onlyOperator {
        _implementation = implementation_;
    }

    /**
     *  @dev Updates the pair token name suffix. This is cosmetic only.
     */
    function updatePairPrefix(string memory _suffix) public onlyOperator {
        suffix = _suffix;
    }
    
    /**
     *  @dev Updates the liquidity providing fee which is dispersed between LPs.
     *  @notice This can be set to a maximum of 5%, but the intention is that it will never be close to that high.
     */
    function updateLiquidityBaseFee(uint256 fee) public onlyOperator {
        require(fee < 500, "Fee cannot be larger than 5%");

        liquidityBaseFee = fee;

        emit FeeChange(msg.sender, fee);
    }

    /**
     *  @dev Checks if a pair exists by checking both combinations of token ordering.
     *  @notice This returns the zero address if no pair is found.
     *  @return pair - The pair address
     */
    function _checkIfPairExists(address token0, address token1) internal view returns (address pair) {
        if (pairs[token0][token1] != address(0)) return pairs[token0][token1];

        if (pairs[token1][token0] != address(0)) return pairs[token1][token0];

        return address(0);
    }

    /**
     *  @dev Creates a ERC1167 minimal proxy of ManaSwap pair. This is only called in @createPair
     *  @notice Pair contracts are not initialized by default
     *  @param implementation - The implementation contract to clone
     *  @return pair - The newly created pair address
     */
    function _createMinimalProxy(address implementation) internal returns (address pair) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            pair := create(0, ptr, 0x37)
        }

        require(pair != address(0), "Contract failed to deploy.");
    }

    /**
     *  @dev ABI Encodes token data to pass into intializer function for newly created pair contracts
     *  @notice The 4th and 5th arguments here are required only due to minimal proxy lacking state variables
     *  @param token0 - The address of token0
     *  @param token1 - The address of token1
     *  @return data - ABI-encoded data to use when initializing pair contracts.
     */
    function _encodeData(address token0, address token1) internal view returns (bytes memory) {
        uint256 unlocked = 1;
        return abi.encode(address(this), token0, token1, true, unlocked);
    }
}