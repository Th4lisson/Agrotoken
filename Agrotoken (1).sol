// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Agrotoken {
    using SafeMath for uint;

    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowance;

    uint public totalSupply;
    string public name = "Agrotoken";
    string public symbol = "AGK";
    uint public decimals = 18;
    uint public maxHoldingAmount;
    uint public maxTxAmount;

    bool public paused = false;
    address public owner;
    uint public taxPercentage = 2; // 2% de taxa
    address public taxCollector;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event Burn(address indexed burner, uint value);
    event TaxCollectorUpdated(address indexed newTaxCollector);
    event TaxApplied(address indexed from, address indexed to, uint taxAmount, uint valueAfterTax);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Contract is not paused");
        _;
    }

    constructor(address _taxCollector) {
        owner = msg.sender;
        taxCollector = _taxCollector; // Definindo a carteira MetaMask como coletor de taxas
        totalSupply = 3000000000000 * 10 ** 18; // 3 trilhões de tokens
        maxHoldingAmount = 1000000000 * 10 ** 18; // 1 bilhão de tokens
        maxTxAmount = 100000000 * 10 ** 18; // 100 milhões de tokens
        balances[msg.sender] = totalSupply; // Definindo o fornecimento inicial para o proprietário
    }

    function balanceOf(address account) public view returns(uint) {
        return balances[account];
    }

    function getAllowance(address account, address spender) public view returns (uint) {
        return allowance[account][spender];
    }

    function pause() public onlyOwner whenNotPaused {
        paused = true;
    }

    function unpause() public onlyOwner whenPaused {
        paused = false;
    }

    function _transfer(address from, address to, uint value) internal whenNotPaused {
        require(to != address(0), 'invalid address');
        uint taxAmount = value.mul(taxPercentage).div(100);
        uint valueAfterTax = value.sub(taxAmount);

        require(value <= maxTxAmount, "Transfer amount exceeds the maxTxAmount");
        require(balanceOf(from) >= value, 'balance too low for transfer and tax');
        require(balances[to].add(valueAfterTax) <= maxHoldingAmount, 'Whale protection: balance exceeds max holding limit');

        balances[from] = balances[from].sub(value);
        balances[to] = balances[to].add(valueAfterTax);
        balances[taxCollector] = balances[taxCollector].add(taxAmount);

        emit Transfer(from, to, valueAfterTax);
        emit Transfer(from, taxCollector, taxAmount);
        emit TaxApplied(from, to, taxAmount, valueAfterTax);
    }

    function transfer(address to, uint value) public returns(bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) public returns(bool) {
        require(allowance[from][msg.sender] >= value, 'allowance too low');
        allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        _transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint value) public whenNotPaused returns(bool) {
        require(spender != address(0), 'invalid address');
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function burn(uint value) public whenNotPaused {
        require(balanceOf(msg.sender) >= value, "Insufficient balance to burn");
        balances[msg.sender] = balances[msg.sender].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Burn(msg.sender, value);
        emit Transfer(msg.sender, address(0), value);
    }

    function mint(address to, uint value) public onlyOwner {
        require(to != address(0), 'invalid address');
        totalSupply = totalSupply.add(value);
        balances[to] = balances[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function setTaxPercentage(uint _taxPercentage) public onlyOwner {
        taxPercentage = _taxPercentage;
    }

    function setTaxCollector(address _taxCollector) public onlyOwner {
        require(_taxCollector != address(0), 'invalid address');
        taxCollector = _taxCollector;
        emit TaxCollectorUpdated(_taxCollector);
    }
}
