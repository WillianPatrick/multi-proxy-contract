// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibDiamond } from "./libraries/LibDiamond.sol";
import { IDiamondCut } from "./interfaces/IDiamondCut.sol";

error FunctionNotFound(bytes4 _functionSelector);

struct DiamondArgs {
    address owner;
    address init;
    bytes initCalldata;
    //bytes32 storageKey; // Added this for dynamic storage    
}

contract Diamond{    
    bool public pausedDiamond;
    bool public removedDiamond;
    uint256 public version;

    error PausedDiamond();
    error PausedFacet();
    error PausedFunction();

    constructor(IDiamondCut.FacetCut[] memory _diamondCut, DiamondArgs memory _args) payable {
        LibDiamond.setContractOwner(_args.owner);
        LibDiamond.setAdmin(address(msg.sender));
        LibDiamond.diamondCut(_diamondCut, _args.init, _args.initCalldata);
        version = 1;
        // Code can be added here to perform actions and set state variables.
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        if(pausedDiamond){
            revert PausedDiamond();
        }

        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }

        bytes4 functionSelector = msg.sig;

        if (ds.functionRoles[functionSelector] != bytes32(0)) {
            require(ds.accessControl[functionSelector][msg.sender], "AccessControl: sender does not have access to this function");
        }
        address facet = ds.facetAddressAndSelectorPosition[msg.sig].facetAddress;
        if(facet == address(0)) {
            revert FunctionNotFound(msg.sig);
        }

        if(ds.pausedFacets[facet]) {
            revert PausedFacet();
        }        
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
             // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }

    receive() external payable {}
}
