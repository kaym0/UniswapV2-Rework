// SPDX-License-Identifier: Any
pragma solidity ^0.8.0;

contract Operator {
    error NotOperator();

    bool hasMultipleOperators;

    mapping (address => bool) public operator;

    constructor() {
        operator[msg.sender] = true;
    }

    modifier onlyOperator {
        if (operator[msg.sender] != true) revert NotOperator();
        _;
    }

    function addOperator(address _operator) public onlyOperator {
        operator[_operator] = true;
    }

    function removeOperator(address _operator) public onlyOperator {
        delete operator[_operator];
    }
}