import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import * as mocha from "mocha-steps";
import { parseEther } from '@ethersproject/units';
import { DiamondInit, DiamondCutFacet, DiamondLoupeFacet,
     OwnershipFacet, ERC20ConstantsFacet, BalancesFacet,
     AllowancesFacet, SupplyRegulatorFacet } from '../typechain-types';
import { assert } from 'chai';
import { getSelectors } from "../scripts/libraries/diamond";

describe("Diamond Global Test", async () => {
    let diamondCutFacet: DiamondCutFacet;
    let diamondLoupeFacet: DiamondLoupeFacet;
    let ownershipFacet: OwnershipFacet;
    let constantsFacet: ERC20ConstantsFacet;
    let balancesFacet: BalancesFacet;
    let allowancesFacet: AllowancesFacet;
    let supplyRegulatorFacet: SupplyRegulatorFacet;

    interface FacetCut {
        facetAddress: string,
        action: FacetCutAction,
        functionSelectors: string[]
    }

    interface FacetToAddress {
        [key: string]: string
    }

    let diamondInit: DiamondInit;

    let owner: SignerWithAddress, admin: SignerWithAddress, 
    user1: SignerWithAddress, user2: SignerWithAddress, user3: SignerWithAddress;

    const totalSupply = parseEther('2500000');
    const transferAmount = parseEther('1000');
    const name = "Token Name";
    const symbol = "SYMBOL";
    const decimals = 18;

    beforeEach(async () => {
        [owner, admin, user1, user2, user3] = await ethers.getSigners();
    });

    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    let calldataAfterDeploy: string;
    let addressDiamond: string;

    let facetToAddressImplementation: FacetToAddress = {};

    let facetCuts: FacetCut[] = [];

    // обслуживающие грани и сам Diamond:

    const FacetNames = [
        'DiamondCutFacet',
        'DiamondLoupeFacet',
        'OwnershipFacet'
    ];
    mocha.step("Deploy the mandatory facets to service the Diamond", async function() {
        for (const FacetName of FacetNames) {
            const Facet = await ethers.getContractFactory(FacetName)
            const facet = await Facet.deploy()
            await facet.deployed();
            facetCuts.push({
              facetAddress: facet.address,
              action: FacetCutAction.Add,
              functionSelectors: getSelectors(facet)
            });
            facetToAddressImplementation[FacetName] = facet.address;
            console.log("   > "+ FacetName +" - "+facet.address);
        };
    });
    
    mocha.step("Deploy the Diamond contract", async function () {
        const diamondArgs = {
            owner: owner.address,
            init: ethers.constants.AddressZero,
            initCalldata: '0x00'
        };
        const Diamond = await ethers.getContractFactory('Diamond')
        const diamond = await Diamond.deploy(facetCuts, diamondArgs)
        await diamond.deployed();
        addressDiamond = diamond.address;
        console.log("       > Diamond: "+ diamond.address + " - Owner: "+ owner.address);
    });

    mocha.step("Initialization of service contracts", async function () {
        diamondCutFacet = await ethers.getContractAt('DiamondCutFacet', addressDiamond);
        diamondLoupeFacet = await ethers.getContractAt('DiamondLoupeFacet', addressDiamond);
        ownershipFacet = await ethers.getContractAt('OwnershipFacet', addressDiamond);
    });

    mocha.step("Ensuring that the facet addresses on the contract match those obtained during the implementation deployment", async function () {
        const addresses = [];
        for (const address of await diamondLoupeFacet.facetAddresses()) {
            addresses.push(address)
        }
        assert.sameMembers(Object.values(facetToAddressImplementation), addresses)
    });

    mocha.step("Get function selectors by their facet addresses", async function () {
        let selectors = getSelectors(diamondCutFacet)
        let result = await diamondLoupeFacet.facetFunctionSelectors(facetToAddressImplementation['DiamondCutFacet'])
        assert.sameMembers(result, selectors)
        selectors = getSelectors(diamondLoupeFacet)
        result = await diamondLoupeFacet.facetFunctionSelectors(facetToAddressImplementation['DiamondLoupeFacet'])
        assert.sameMembers(result, selectors)
        selectors = getSelectors(ownershipFacet)
        result = await diamondLoupeFacet.facetFunctionSelectors(facetToAddressImplementation['OwnershipFacet'])
        assert.sameMembers(result, selectors)
    });

    mocha.step("Get facet addresses by selectors related to these facets", async function () {
        assert.equal(
            facetToAddressImplementation['DiamondCutFacet'],
            await diamondLoupeFacet.facetAddress('0x1f931c1c') //diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata)
        )
        assert.equal(
            facetToAddressImplementation['DiamondLoupeFacet'],
            await diamondLoupeFacet.facetAddress('0x7a0ed627') // facets()
        )
        assert.equal(
            facetToAddressImplementation['DiamondLoupeFacet'],
            await diamondLoupeFacet.facetAddress('0xadfca15e') // facetFunctionSelectors(address _facet)
        )
        assert.equal(
            facetToAddressImplementation['OwnershipFacet'],
            await diamondLoupeFacet.facetAddress('0xf2fde38b') // transferOwnership(address _newOwner)
        )
    });

    mocha.step("Transfer the right to change implementations and back", async function () {
        await ownershipFacet.connect(owner).transferOwnership(admin.address);
        assert.equal(await ownershipFacet.owner(), admin.address);
        await ownershipFacet.connect(admin).transferOwnership(owner.address);
        assert.equal(await ownershipFacet.owner(), owner.address);
    });

    // ERC20:

    mocha.step("Deploy the contract that initializes variable values for the functions name(), symbol(), etc. during the diamondCut function call", async function() {
        const DiamondInit = await ethers.getContractFactory('DiamondInit');
        diamondInit = await DiamondInit.deploy();
        await diamondInit.deployed();
    });

    mocha.step("Forming calldata that will be called from Diamond via delegatecall to initialize variables during the diamondCut function call", async function () {
        calldataAfterDeploy = diamondInit.interface.encodeFunctionData('initERC20', [
            name,
            symbol,
            decimals,
            admin.address,
            totalSupply
        ]);
        console.log("       > Token: "+ name + " - Symbol: "+ symbol + " - Decimals: "+ decimals + " - Total Suply: "+ totalSupply + " - Admin: "+ admin.address);
    });

    mocha.step("Deploy implementation with constants", async function () {
        const ConstantsFacet = await ethers.getContractFactory("ERC20ConstantsFacet");
        const constantsFacet = await ConstantsFacet.deploy();
        constantsFacet.deployed();
        const facetCuts = [{
            facetAddress: constantsFacet.address,
            action: FacetCutAction.Add,
            functionSelectors: getSelectors(constantsFacet)
        }];
        await diamondCutFacet.connect(owner).diamondCut(facetCuts, diamondInit.address, calldataAfterDeploy);
        facetToAddressImplementation['ERC20ConstantsFacet'] = constantsFacet.address;
    });

    mocha.step("Initialization of the implementation with constants", async function () {
        constantsFacet = await ethers.getContractAt('ERC20ConstantsFacet', addressDiamond);
    });

    mocha.step("Checking for the presence of constants", async function () {
        assert.equal(await constantsFacet.name(), name);
        assert.equal(await constantsFacet.symbol(), symbol);
        assert.equal(await constantsFacet.decimals(), decimals);
        assert.equal(await constantsFacet.admin(), admin.address);
    });

    mocha.step("Deploying implementation with a transfer function", async function () {
        const BalancesFacet = await ethers.getContractFactory("BalancesFacet");
        const balancesFacet = await BalancesFacet.deploy();
        balancesFacet.deployed();
        const facetCuts = [{
            facetAddress: balancesFacet.address,
            action: FacetCutAction.Add,
            functionSelectors: getSelectors(balancesFacet)
        }];
        await diamondCutFacet.connect(owner).diamondCut(facetCuts, ethers.constants.AddressZero, "0x00");
        facetToAddressImplementation['BalancesFacet'] = balancesFacet.address;
    });

    mocha.step("Initialization of the implementation with balances and transfer", async function () {
        balancesFacet = await ethers.getContractAt('BalancesFacet', addressDiamond);
    });

    mocha.step("Checking the view function of the implementation with balances and transfer", async function () {
        expect(await balancesFacet.totalSupply()).to.be.equal(totalSupply);
        expect(await balancesFacet.balanceOf(admin.address)).to.be.equal(totalSupply);
    });

    mocha.step("Checking the transfer", async function () {
        await balancesFacet.connect(admin).transfer(user1.address, transferAmount);
        expect(await balancesFacet.balanceOf(admin.address)).to.be.equal(totalSupply.sub(transferAmount));
        expect(await balancesFacet.balanceOf(user1.address)).to.be.equal(transferAmount);
        await balancesFacet.connect(user1).transfer(admin.address, transferAmount);
    });

    mocha.step("Deploying the implementation with allowances", async function () {
        const AllowancesFacet = await ethers.getContractFactory("AllowancesFacet");
        const allowancesFacet = await AllowancesFacet.deploy();
        allowancesFacet.deployed();
        const facetCuts = [{
            facetAddress: allowancesFacet.address,
            action: FacetCutAction.Add,
            functionSelectors: getSelectors(allowancesFacet)
        }];
        await diamondCutFacet.connect(owner).diamondCut(facetCuts, ethers.constants.AddressZero, "0x00");
        facetToAddressImplementation['ERC20ConstantsFacet'] = allowancesFacet.address;
    });

    mocha.step("Initialization of the implementation with balances and transfer allowance, approve, transferFrom...", async function () {
        allowancesFacet = await ethers.getContractAt('AllowancesFacet', addressDiamond);
    });

    mocha.step("Testing the functions allowance, approve, transferFrom", async function () {
        expect(await allowancesFacet.allowance(admin.address, user1.address)).to.equal(0);
        const valueForApprove = parseEther("100");
        const valueForTransfer = parseEther("30");
        await allowancesFacet.connect(admin).approve(user1.address, valueForApprove);
        expect(await allowancesFacet.allowance(admin.address, user1.address)).to.equal(valueForApprove);
        await allowancesFacet.connect(user1).transferFrom(admin.address, user2.address, valueForTransfer);
        expect(await balancesFacet.balanceOf(user2.address)).to.equal(valueForTransfer);
        expect(await balancesFacet.balanceOf(admin.address)).to.equal(totalSupply.sub(valueForTransfer));
        expect(await allowancesFacet.allowance(admin.address, user1.address)).to.equal(valueForApprove.sub(valueForTransfer));
    });

    mocha.step("Deploying the implementation with mint and burn", async function () {
        const SupplyRegulatorFacet = await ethers.getContractFactory("SupplyRegulatorFacet");
        supplyRegulatorFacet = await SupplyRegulatorFacet.deploy();
        supplyRegulatorFacet.deployed();
        const facetCuts = [{
            facetAddress: supplyRegulatorFacet.address,
            action: FacetCutAction.Add,
            functionSelectors: getSelectors(supplyRegulatorFacet)
        }];
        await diamondCutFacet.connect(owner).diamondCut(facetCuts, ethers.constants.AddressZero, "0x00");
        facetToAddressImplementation['SupplyRegulatorFacet'] = supplyRegulatorFacet.address;
    });

    mocha.step("Initialization of the implementation with mint and burn functions", async function () {
        supplyRegulatorFacet = await ethers.getContractAt('SupplyRegulatorFacet', addressDiamond);
    });
    
    mocha.step("Checking the mint and burn functions", async function () {
        const mintAmount = parseEther('1000');
        const burnAmount = parseEther('500');
        await supplyRegulatorFacet.connect(admin).mint(user3.address, mintAmount);
        expect(await balancesFacet.balanceOf(user3.address)).to.equal(mintAmount);
        expect(await balancesFacet.totalSupply()).to.be.equal(totalSupply.add(mintAmount));
        await supplyRegulatorFacet.connect(admin).burn(user3.address, burnAmount);
        expect(await balancesFacet.balanceOf(user3.address)).to.equal(mintAmount.sub(burnAmount));
        expect(await balancesFacet.totalSupply()).to.be.equal(totalSupply.add(mintAmount).sub(burnAmount));
    });

    mocha.step("Removing the diamondCut function for further immutability", async function () {
        const facetCuts = [{
            facetAddress: ethers.constants.AddressZero,
            action: FacetCutAction.Remove,
            functionSelectors: ['0x1f931c1c'] //diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata)
        }];
        await diamondCutFacet.connect(owner).diamondCut(facetCuts, ethers.constants.AddressZero, "0x00");
    });
});
