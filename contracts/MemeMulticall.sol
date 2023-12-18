// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IMemeFactory {
    function getMemeCount() external view returns (uint256);
    function getMemeByIndex(uint256 index) external view returns (address);
    function getIndexByMeme(address meme) external view returns (uint256);
    function getIndexBySymbol(string memory symbol) external view returns (uint256);
}

interface IMeme {
    function reserveBase() external view returns (uint256);
    function RESERVE_VIRTUAL_BASE() external view returns (uint256);
    function reserveMeme() external view returns (uint256);
    function getPrice() external view returns (uint256);
    function claimableBase(address account) external view returns (uint256);
    function claimableMeme(address account) external view returns (uint256);
    function totalFeesBase() external view returns (uint256);
    function totalFeesMeme() external view returns (uint256);
}

interface IChainlinkOracle {
    function latestAnswer() external view returns (uint256);
}

contract Multicall {

    /*----------  CONSTANTS  --------------------------------------------*/

    address public constant ORACLE = 0x0000000000000000000000000000000000000000;
    uint256 public constant FEE = 100;
    uint256 public constant DIVISOR = 10000;
    uint256 public constant PRECISION = 1e18;

    /*----------  STATE VARIABLES  --------------------------------------*/

    address public immutable memeFactory;   
    address public immutable base;

    struct MemeData {
        address meme;
        string name;
        string symbol;
        
        uint256 reserveVirtualBase;
        uint256 reserveRealBase;
        uint256 reserveRealMeme;

        uint256 price;
        uint256 tvl;
        uint256 totalFeesBase;
        uint256 totalFeesMeme;

        uint256 accountbase;
        uint256 accountBalance;
        uint256 accountClaimableBase;
        uint256 accountClaimableMeme;
    }

    /*----------  FUNCTIONS  --------------------------------------------*/

    constructor(address _memeFactory, address _base) {
        memeFactory = _memeFactory;
        base = _base;
    }

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/

    function getBasePrice() public view returns (uint256) {
        if (ORACLE == address(0)) return 1e18;
        return IChainlinkOracle(ORACLE).latestAnswer() * 1e18 / 1e8;
    }

    function getMemeData(uint256 index, address account) external view returns (MemeData memory memeData) {

        memeData.meme = IMemeFactory(memeFactory).getMemeByIndex(index);
        memeData.name = IERC20Metadata(memeData.meme).name();
        memeData.symbol = IERC20Metadata(memeData.meme).symbol();

        memeData.reserveVirtualBase = IMeme(memeData.meme).RESERVE_VIRTUAL_BASE();
        memeData.reserveRealBase = IMeme(memeData.meme).reserveBase();
        memeData.reserveRealMeme = IMeme(memeData.meme).reserveMeme();

        memeData.price = IMeme(memeData.meme).getPrice() * getBasePrice() / 1e18;
        memeData.tvl = (memeData.reserveRealBase + memeData.reserveVirtualBase) * 2 * getBasePrice() / 1e18;
        memeData.totalFeesBase = IMeme(memeData.meme).totalFeesBase();
        memeData.totalFeesMeme = IMeme(memeData.meme).totalFeesMeme();

        memeData.accountbase = IERC20(base).balanceOf(account);
        memeData.accountBalance = IERC20(memeData.meme).balanceOf(account);
        memeData.accountClaimableBase = IMeme(memeData.meme).claimableBase(account);
        memeData.accountClaimableMeme = IMeme(memeData.meme).claimableMeme(account);

    }

    function quoteBuyIn(address meme, uint256 input, uint256 slippageTolerance) external view returns(uint256 output, uint256 slippage, uint256 minOutput, uint256 autoMinOutput) {
        uint256 fee = input * FEE / DIVISOR;
        uint256 newReserveBase = IMeme(meme).reserveBase() + IMeme(meme).RESERVE_VIRTUAL_BASE() + input - fee;
        uint256 newReserveMeme = (IMeme(meme).reserveBase() + IMeme(meme).RESERVE_VIRTUAL_BASE()) * IMeme(meme).reserveMeme() / newReserveBase;

        output = IMeme(meme).reserveMeme() - newReserveMeme;
        slippage = 100 * (1e18 - (output * IMeme(meme).getPrice() / input));
        minOutput = (input * 1e18 / IMeme(meme).getPrice()) * slippageTolerance / DIVISOR;
        autoMinOutput = (input * 1e18 / IMeme(meme).getPrice()) * ((DIVISOR * 1e18) - ((slippage + 1e18) * 100)) / (DIVISOR * 1e18);
    }

    function quoteBuyOut(address meme, uint256 input, uint256 slippageTolerance) external view returns (uint256 output, uint256 slippage, uint256 minOutput, uint256 autoMinOutput) {
        uint256 oldReserveBase = IMeme(meme).RESERVE_VIRTUAL_BASE() + IMeme(meme).reserveBase();

        output = DIVISOR * ((oldReserveBase * IMeme(meme).reserveMeme() / (IMeme(meme).reserveMeme() - input)) - oldReserveBase) / (DIVISOR - FEE);
        slippage = 100 * (1e18 - (input * IMeme(meme).getPrice() / output));
        minOutput = input * slippageTolerance / DIVISOR;
        autoMinOutput = input * ((DIVISOR * 1e18) - ((slippage + 1e18) * 100)) / (DIVISOR * 1e18);
    }

    function quoteSellIn(address meme, uint256 input, uint256 slippageTolerance) external view returns (uint256 output, uint256 slippage, uint256 minOutput, uint256 autoMinOutput) {
        uint256 fee = input * FEE / DIVISOR;
        uint256 newReserveMeme = IMeme(meme).reserveMeme() + input - fee;
        uint256 newReserveBase = (IMeme(meme).RESERVE_VIRTUAL_BASE() + IMeme(meme).reserveBase()) * IMeme(meme).reserveMeme() / newReserveMeme;

        output = (IMeme(meme).RESERVE_VIRTUAL_BASE() + IMeme(meme).reserveBase()) - newReserveBase;
        slippage = 100 * (1e18 - (output * 1e18 / (input * IMeme(meme).getPrice() / 1e18)));
        minOutput = input * IMeme(meme).getPrice() /1e18 * slippageTolerance / DIVISOR;
        autoMinOutput = input * IMeme(meme).getPrice() /1e18 * ((DIVISOR * 1e18) - ((slippage + 1e18) * 100)) / (DIVISOR * 1e18);
    }

    function quoteSellOut(address meme, uint256 input, uint256 slippageTolerance) external view returns (uint256 output, uint256 slippage, uint256 minOutput, uint256 autoMinOutput) {
        uint256 oldReserveBase = IMeme(meme).RESERVE_VIRTUAL_BASE() + IMeme(meme).reserveBase();
        
        output = DIVISOR * ((oldReserveBase * IMeme(meme).reserveMeme()  / (oldReserveBase - input)) - IMeme(meme).reserveMeme()) / (DIVISOR - FEE);
        slippage = 100 * (1e18 - (input * 1e18 / (output * IMeme(meme).getPrice() / 1e18)));
        minOutput = input * slippageTolerance / DIVISOR;
        autoMinOutput = input * ((DIVISOR * 1e18) - ((slippage + 1e18) * 100)) / (DIVISOR * 1e18);
    }

}