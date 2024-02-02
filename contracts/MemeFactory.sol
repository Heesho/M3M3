// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Meme.sol";

contract MemeFactory is Ownable {

    /*----------  CONSTANTS  --------------------------------------------*/

    uint256 public constant NAME_MAX_LENGTH = 80;
    uint256 public constant SYMBOL_MAX_LENGTH = 8;
    uint256 public constant MIN_AMOUNT_IN = 100000000000000000; // 0.1 ETH

    /*----------  STATE VARIABLES  --------------------------------------*/
    
    address public immutable base;
    address public treasury;

    uint256 public index = 1;
    mapping(uint256=>address) public index_Meme;
    mapping(address=>uint256) public meme_Index;
    mapping(string=>uint256) public symbol_Index;

    /*----------  ERRORS ------------------------------------------------*/

    error MemeFactory__NameRequired();
    error MemeFactory__SymbolRequired();
    error MemeFactory__SymbolExists();
    error MemeFactory__NameLimitExceeded();
    error MemeFactory__SymbolLimitExceeded();
    error MemeFactory__InsufficientAmountIn();

    /*----------  EVENTS ------------------------------------------------*/
    
    event MemeFactory__MemeCreated(uint256 index, address meme);
    event MemeFactory__TreasuryUpdated(address treasury);

    /*----------  MODIFIERS  --------------------------------------------*/

    /*----------  FUNCTIONS  --------------------------------------------*/

    constructor(address _base, address _treasury) {
        base = _base;
        treasury = _treasury;
    }
        
    function createMeme(
        string memory name,
        string memory symbol,
        string memory uri,
        address account,
        uint256 amountIn
    ) external returns (address) {
        if (amountIn < MIN_AMOUNT_IN) revert MemeFactory__InsufficientAmountIn();
        if (symbol_Index[symbol] != 0) revert MemeFactory__SymbolExists();
        if (bytes(name).length == 0) revert MemeFactory__NameRequired();
        if (bytes(symbol).length == 0) revert MemeFactory__SymbolRequired();
        if (bytes(name).length > NAME_MAX_LENGTH) revert MemeFactory__NameLimitExceeded();
        if (bytes(symbol).length > SYMBOL_MAX_LENGTH) revert MemeFactory__SymbolLimitExceeded();

        address meme = address(new Meme(name, symbol, uri, base, account));
        address preMeme = Meme(meme).preMeme();
        index_Meme[index] = meme;
        meme_Index[meme] = index;
        symbol_Index[symbol] = index;

        emit MemeFactory__MemeCreated(index, meme);
        index++;

        IERC20(base).transferFrom(msg.sender, address(this), amountIn);
        IERC20(base).approve(preMeme, amountIn);
        PreMeme(preMeme).contribute(account, amountIn);

        return meme;
    }

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit MemeFactory__TreasuryUpdated(_treasury);
    }

}