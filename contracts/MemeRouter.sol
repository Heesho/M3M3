// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMemeFactory {
    function createMeme(string memory name, string memory symbol, uint256 amountIn) external returns (address);
}

interface IMeme {
    function buy(uint256 amountIn, uint256 minAmountOut, uint256 expireTimestamp, address to, address provider) external;
    function sell(uint256 amountIn, uint256 minAmountOut, uint256 expireTimestamp, address to, address provider) external;
    function claimFees(address account) external;
}

interface IBase {
    function deposit() external payable;
    function withdraw(uint) external;
}

contract MemeRouter {
    address public immutable base;
    address public immutable factory;
    
    constructor(address _base, address _factory) {
        base = _base;
        factory = _factory;
    }

    function buy(
        address meme,
        uint256 minAmountOut,
        uint256 expireTimestamp
    ) external payable {
        IBase(base).deposit{value: msg.value}();
        IERC20(base).approve(meme, msg.value);
        IMeme(meme).buy(msg.value, minAmountOut, expireTimestamp, address(this), address(0));

        IERC20(meme).transfer(msg.sender, IERC20(meme).balanceOf(address(this)));
        IERC20(base).transfer(msg.sender, IERC20(base).balanceOf(address(this)));
    }

    function sell(
        address meme,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 expireTimestamp
    ) external {
        IERC20(meme).approve(meme, amountIn);
        IMeme(meme).sell(amountIn, minAmountOut, expireTimestamp, address(this), address(0));

        uint256 baseBalance = IERC20(base).balanceOf(address(this));
        IBase(base).withdraw(baseBalance);
        (bool success, ) = msg.sender.call{value: baseBalance}("");
        require(success, "Failed to send ETH");
        IERC20(meme).transfer(msg.sender, IERC20(meme).balanceOf(address(this)));
    }

    function claimFees(address[] calldata memes) external {
        for (uint256 i = 0; i < memes.length; i++) {
            IMeme(memes[i]).claimFees(msg.sender);
        }
    }

    function createMeme(
        string memory name,
        string memory symbol
    ) external payable returns (address) {
        IBase(base).deposit{value: msg.value}();
        IERC20(base).approve(factory, msg.value);
        address meme = IMemeFactory(factory).createMeme(name, symbol, msg.value);
        IERC20(meme).transfer(msg.sender, IERC20(meme).balanceOf(address(this)));
        IERC20(base).transfer(msg.sender, IERC20(base).balanceOf(address(this)));
        return meme;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}