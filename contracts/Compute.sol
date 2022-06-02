// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Create2.sol";

contract Compute {

    function computeAddress(bytes32 salt, address implementation) public view returns (address, bytes32) {
        return(
            Create2.computeAddress(
                salt,
                keccak256(getContractCreationCode(implementation)),
                address(this)
            ),  keccak256(getContractCreationCode(implementation)));
    }

    function getContractCreationCode(address logic) internal pure returns (bytes memory) {
        bytes10 creation = 0x3d602d80600a3d3981f3;
        bytes10 prefix = 0x363d3d373d3d3d363d73;
        bytes20 targetBytes = bytes20(logic);
        bytes15 _suffix = 0x5af43d82803e903d91602b57fd5bf3;
        return abi.encodePacked(creation, prefix, targetBytes, _suffix);
    }

    function getHashedCode(address logic) public pure returns (bytes32) {
        return keccak256(getContractCreationCode(logic));
    }
}