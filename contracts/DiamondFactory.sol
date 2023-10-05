// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Diamond } from "./Diamond.sol";
import { IDiamondCut } from "./interfaces/IDiamondCut.sol";
import { DiamondCutFacet } from "./DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "./DiamondLoupeFacet.sol";
import { OwnershipFacet } from "./OwnershipFacet.sol";

contract DiamondFactory {

    event DiamondCreated(address indexed diamondAddress, address indexed owner);

    address[] public diamonds;

    function createDiamond(Diamond.DiamondArgs memory _args) public returns (address) {
        // 1. Create each facet dynamically
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();

        // 2. Configure the Diamond with the basic functionalities of the facets
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](3);

        // DiamondCutFacet selectors
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: new bytes4[](1) {
                IDiamondCut.diamondCut.selector
            }
        });

        // DiamondLoupeFacet selectors
        facetCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: new bytes4[](4) {
                DiamondLoupeFacet.facets.selector,
                DiamondLoupeFacet.facetFunctionSelectors.selector,
                DiamondLoupeFacet.facetAddresses.selector,
                DiamondLoupeFacet.facetAddress.selector
            }
        });

        // OwnershipFacet selectors
        facetCuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: new bytes4[](2) {
                OwnershipFacet.transferOwnership.selector,
                OwnershipFacet.owner.selector
            }
        });

        // 3. Register the functionalities in the newly created Diamond
        Diamond diamond = new Diamond(facetCuts, _args);
        diamonds.push(address(diamond));
        emit DiamondCreated(address(diamond), _args.owner);
        return address(diamond);
    }

    // Retrieve the total number of Diamonds created by this factory.
    function getTotalDiamonds() external view returns (uint256) {
        return diamonds.length;
    }

    // Retrieve the address of a specific Diamond.
    function getDiamondAddress(uint256 _index) external view returns (address) {
        require(_index < diamonds.length, "Index out of bounds");
        return diamonds[_index];
    }
}