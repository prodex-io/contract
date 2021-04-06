pragma solidity >=0.5.16;

import './IERC20.sol';

interface IPdx is IERC20 {
    function mint(address to, uint256 amount) external returns (bool);
}