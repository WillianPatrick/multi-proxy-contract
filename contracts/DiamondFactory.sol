// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { Diamond, DiamondArgs } from "./Diamond.sol";
import { IDiamond } from "./interfaces/IDiamond.sol";
import { IDiamondCut } from "./interfaces/IDiamondCut.sol";
import { DiamondCutFacet } from "./facets/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "./facets/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "./facets/OwnershipFacet.sol";

contract DiamondFactory {

    event DiamondCreated(address indexed diamondAddress, address indexed owner);
    address private _owner;
    address[] public diamonds;
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not contract owner");
        _;
    }

    constructor() {
        _owner = msg.sender;
        // 1. Create each facet dynamically
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
    }

    function createDiamond(DiamondArgs memory _args) public onlyOwner returns (address) {
        _args.owner = _args.owner == address(0) ? msg.sender : _args.owner;
        
        // 2. Configure the Diamond with the basic functionalities of the facets
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](3);

        // DiamondCutFacet selectors
        bytes4[] memory diamondCutSelectors = new bytes4[](1);
        diamondCutSelectors[0] = IDiamondCut.diamondCut.selector;
        facetCuts[0] = IDiamond.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: diamondCutSelectors
        });

        // DiamondLoupeFacet selectors
        bytes4[] memory diamondLoupeSelectors = new bytes4[](4);
        diamondLoupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        diamondLoupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        diamondLoupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        diamondLoupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        facetCuts[1] = IDiamond.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: diamondLoupeSelectors
        });

        // OwnershipFacet selectors
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = OwnershipFacet.transferOwnership.selector;
        ownershipSelectors[1] = OwnershipFacet.owner.selector;
        facetCuts[2] = IDiamond.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
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
