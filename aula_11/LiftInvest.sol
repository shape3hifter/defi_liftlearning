// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "./IUniswapV2Router02.sol";
import "./IERC20.sol";

contract LiftInvest {
    IUniswapV2Router02 uniswap_router =
        IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

    uint256[] allocation;
    address[] tokens;
    address[][] paths;

    mapping(address => mapping(address => uint256)) shares; // Token address => User address => Amount of shares

    constructor(
        uint256[] memory _allocation,
        address[] memory _tokens,
        address[][] memory _paths
    ) payable {
        require(_allocation.length == _tokens.length);
        require(_tokens.length == _paths.length);

        allocation = _allocation;
        tokens = _tokens;
        paths = _paths;
    }

    receive() external payable {}

    function deposit() public payable {
        uint256[] memory amounts = new uint256[](tokens.length);
        uint256 quota_price = 0;

        for (uint8 i = 0; i < allocation.length; i++) {
            amounts[i] = uniswap_router.getAmountsIn(allocation[i], paths[i])[
                0
            ];
            quota_price += amounts[i];
        }

        uint256 n_quotas = msg.value / quota_price;

        for (uint8 i = 0; i < allocation.length; i++) {
            address _token = tokens[i];
            uint256 _amount = amounts[i] * n_quotas;

            uint256[] memory result = uniswap_router.swapExactETHForTokens{
                value: _amount
            }(1, paths[i], address(this), block.timestamp + 1000000);

            uint256 bought = result[result.length - 1];
            shares[_token][msg.sender] += bought;
        }
    }

    function withdraw(uint256 _sell_pct) public {
        require(_sell_pct > 0, "SELL PCT MUST BE > 0");
        require(_sell_pct <= 100, "SELL PCT MUST BE <= 100");

        uint256 eth_amount = 0;

        for (uint8 i = 0; i < allocation.length; i++) {
            address _token = tokens[i];
            uint256 shares_amount = (shares[tokens[i]][msg.sender] *
                _sell_pct) / 100;

            address[] memory path = new address[](paths[i].length);
            for (uint8 j = 0; j < paths[i].length; j++) {
                path[j] = paths[i][paths[i].length - j - 1];
            }

            require(
                IERC20(_token).approve(address(uniswap_router), shares_amount),
                "approve failed"
            );

            uint256[] memory result = uniswap_router.swapExactTokensForETH(
                shares_amount,
                1,
                path,
                address(this),
                block.timestamp + 1000000
            );

            shares[_token][msg.sender] -= result[0];
            eth_amount += result[result.length - 1];
        }

        payable(msg.sender).transfer(eth_amount);
    }
}
