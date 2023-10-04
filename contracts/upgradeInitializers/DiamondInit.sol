// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibERC20Constants } from "../libraries/ERC20/LibConstants.sol";
import { LibBalances } from "../libraries/ERC20/LibBalances.sol";

contract DiamondInit {    

    function initERC20(string calldata _name, string calldata _symbol, uint8 _decimals, address _admin, uint256 _totalSupply) external {
        LibERC20Constants.ConstantsStates storage constantsStorage = LibERC20Constants.diamondStorage();
        constantsStorage.name = _name;
        constantsStorage.symbol = _symbol;
        constantsStorage.decimals = _decimals;
        constantsStorage.admin = _admin;
        LibBalances.mint(_admin, _totalSupply);
    }
}
