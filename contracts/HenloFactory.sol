// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IKeyFactory {
    function createKey(string memory name, string memory symbol, address base) external returns (address);
}

interface IKey {
    function preKey() external view returns (address);
}

interface IPreKey {
    function contribute(address account, uint256 amount) external;
}

contract HenloFactory is Ownable {

    /*----------  CONSTANTS  --------------------------------------------*/

    uint256 public constant NAME_MAX_LENGTH = 80;
    uint256 public constant SYMBOL_MAX_LENGTH = 8;
    uint256 public constant MIN_AMOUNT_IN = 100000000000000000; // 0.1 ETH

    /*----------  STATE VARIABLES  --------------------------------------*/
    
    address public immutable base;
    address public treasury;

    address public keyFactory;
    // address public catalog;

    uint256 public index = 1;
    mapping(uint256=>address) public index_Key;
    mapping(address=>uint256) public key_Index;
    mapping(string=>uint256) public symbol_Index;

    /*----------  ERRORS ------------------------------------------------*/

    error HenloFactory__NameRequired();
    error HenloFactory__SymbolRequired();
    error HenloFactory__SymbolExists();
    error HenloFactory__NameLimitExceeded();
    error HenloFactory__SymbolLimitExceeded();
    error HenloFactory__InsufficientAmountIn();

    /*----------  EVENTS ------------------------------------------------*/
    
    event HenloFactory__HenloCreated(uint256 index, address key);
    event HenloFactory__TreasuryUpdated(address treasury);

    /*----------  MODIFIERS  --------------------------------------------*/

    /*----------  FUNCTIONS  --------------------------------------------*/

    constructor(address _base, address _treasury, address _keyFactory) {
        base = _base;
        treasury = _treasury;
        keyFactory = _keyFactory;
    }
        
    function createHenlo(
        string memory name,
        string memory symbol,
        address account,
        uint256 amountIn
    ) external returns (address) {
        if (amountIn < MIN_AMOUNT_IN) revert HenloFactory__InsufficientAmountIn();
        if (symbol_Index[symbol] != 0) revert HenloFactory__SymbolExists();
        if (bytes(name).length == 0) revert HenloFactory__NameRequired();
        if (bytes(symbol).length == 0) revert HenloFactory__SymbolRequired();
        if (bytes(name).length > NAME_MAX_LENGTH) revert HenloFactory__NameLimitExceeded();
        if (bytes(symbol).length > SYMBOL_MAX_LENGTH) revert HenloFactory__SymbolLimitExceeded();

        address key = IKeyFactory(keyFactory).createKey(name, symbol, base);
        address preKey = IKey(key).preKey();
        index_Key[index] = key;
        key_Index[key] = index;
        symbol_Index[symbol] = index;

        emit HenloFactory__HenloCreated(index, key);
        index++;

        IERC20(base).transferFrom(msg.sender, address(this), amountIn);
        IERC20(base).approve(preKey, amountIn);
        IPreKey(preKey).contribute(account, amountIn);

        return key;
    }

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit HenloFactory__TreasuryUpdated(_treasury);
    }

    // set key factory?
    // update min amount in?

}