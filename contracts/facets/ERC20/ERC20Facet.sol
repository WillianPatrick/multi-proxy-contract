// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

library TokenStorage {

    struct TokenData {
        // ERC20 state variables
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        uint256 totalSupply;

        // ERC20 details
        string name;
        string symbol;
        uint8 decimals;

        // Access control
        address owner;
        mapping(bytes32 => mapping(address => bool)) roles;

        // Pausable
        bool paused;
    }

    function tokenStorage(bytes32 tokenKey) internal pure returns (TokenData storage ds) {
        bytes32 position = tokenKey;
        assembly {
            ds.slot := position
        }
    }
}

contract ERC20Facet is ERC20Burnable, Pausable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 private _tokenKey;

    constructor(string memory name, string memory symbol, uint256 totalSupply, uint256 decimals) ERC20(name, symbol) {
        _tokenKey = keccak256(abi.encodePacked(name, symbol));
        TokenStorage.TokenData storage ds = TokenStorage.tokenStorage(_tokenKey);
        ds.name = name;
        ds.symbol = symbol;
        ds.decimals = uint8(decimals);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        ds.balances[msg.sender] = totalSupply * 10 ** decimals;
        ds.totalSupply = totalSupply * 10 ** decimals;
    }


    function pause() public onlyRole(PAUSER_ROLE) {
        TokenStorage.TokenData storage ds = TokenStorage.tokenStorage(_tokenKey);
        require(!ds.paused, "Already paused");
        ds.paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        TokenStorage.TokenData storage ds = TokenStorage.tokenStorage(_tokenKey);
        require(ds.paused, "Already unpaused");
        ds.paused = false;
        emit Unpaused(msg.sender);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function balanceOf(address account) public view override returns (uint256) {
        TokenStorage.TokenData storage ds = TokenStorage.tokenStorage(_tokenKey);
        return ds.balances[account];
    }

    function totalSupply() public view override returns (uint256) {
        TokenStorage.TokenData storage ds = TokenStorage.tokenStorage(_tokenKey);
        return ds.totalSupply;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        TokenStorage.TokenData storage ds = TokenStorage.tokenStorage(_tokenKey);
        return ds.allowances[owner][spender];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        TokenStorage.TokenData storage ds = TokenStorage.tokenStorage(_tokenKey);
        uint256 currentAllowance = ds.allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual override{
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        TokenStorage.TokenData storage ds = TokenStorage.tokenStorage(_tokenKey);
        ds.balances[sender] = ds.balances[sender] - amount;
        ds.balances[recipient] = ds.balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual override{
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        TokenStorage.TokenData storage ds = TokenStorage.tokenStorage(_tokenKey);
        ds.allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function burn(uint256 amount) public virtual override {
        TokenStorage.TokenData storage ds = TokenStorage.tokenStorage(_tokenKey);
        require(ds.balances[msg.sender] >= amount, "ERC20: burn amount exceeds balance");
        ds.balances[msg.sender] = ds.balances[msg.sender] - amount;
        ds.totalSupply = ds.totalSupply - amount;
        emit Transfer(msg.sender, address(0), amount);
    }
    
    function burnFrom(address account, uint256 amount) public virtual override {
        uint256 decreasedAllowance = allowance(account, _msgSender()) - amount;

        TokenStorage.TokenData storage ds = TokenStorage.tokenStorage(_tokenKey);
        ds.allowances[account][_msgSender()] = decreasedAllowance;
        _burn(account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual override{
        require(account != address(0), "ERC20: burn from the zero address");

        TokenStorage.TokenData storage ds = TokenStorage.tokenStorage(_tokenKey);
        ds.balances[account] = ds.balances[account] - amount;
        ds.totalSupply = ds.totalSupply - amount;
        emit Transfer(account, address(0), amount);
    }
}