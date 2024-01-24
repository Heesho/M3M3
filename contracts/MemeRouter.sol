// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMemeFactory {
    function createMeme(string memory name, string memory symbol, string memory uri, address account, uint256 amountIn) external returns (address);
}

interface IMeme {
    function preMeme() external view returns (address);
    function buy(uint256 amountIn, uint256 minAmountOut, uint256 expireTimestamp, address to, address provider) external;
    function sell(uint256 amountIn, uint256 minAmountOut, uint256 expireTimestamp, address to) external;
    function claimFees(address account) external;
    function updateStatus(address account, string memory status) external;
}

interface IPreMeme {
    function endTimestamp() external view returns (uint256);
    function ended() external view returns (bool);
    function totalBaseContributed() external view returns (uint256);
    function totalMemeBalance() external view returns (uint256);
    function contribute(address account, uint256 amount) external;
    function redeem(address account) external;
    function openMarket() external;
}

interface IBase {
    function deposit() external payable;
    function withdraw(uint) external;
}

contract MemeRouter is Ownable {

    uint256 public constant STATUS_UPDATE_FEE = 10 * 1e18;

    address public immutable base;
    address public immutable factory;

    mapping(address => address) public referrals; // account => affiliate

    event MemeRouter__Buy(address indexed meme, address indexed account, address indexed affiliate, uint256 amountIn, uint256 amountOut, uint256 timestamp);
    event MemeRouter__Sell(address indexed meme, address indexed account, uint256 amountIn, uint256 amountOut, uint256 timestamp);
    event MemeRouter__AffiliateSet(address indexed account, address indexed affiliate);
    event MemeRouter__ClaimFees(address indexed meme, address indexed account);
    event MemeRouter__MemeCreated(address indexed meme, address indexed account);
    event MemeRouter__StatusUpdated(address indexed meme, address indexed account, string status);
    event MemeRouter__Contributed(address indexed meme, address indexed account, uint256 amount);
    event MemeRouter__Redeemed(address indexed meme, address indexed account, uint256 amount);
    event MemeRouter__MarketOpened(address indexed meme, uint256 totalBaseContributed, uint256 totalMemeBalance);
    
    constructor(address _factory, address _base) {
        factory = _factory;
        base = _base;
    }

    function buy(
        address meme,
        address affiliate,
        uint256 minAmountOut,
        uint256 expireTimestamp
    ) external payable {
        if (referrals[msg.sender] == address(0) && affiliate != address(0)) {
            referrals[msg.sender] = affiliate;
            emit MemeRouter__AffiliateSet(msg.sender, affiliate);
        }

        IBase(base).deposit{value: msg.value}();
        IERC20(base).approve(meme, msg.value);
        IMeme(meme).buy(msg.value, minAmountOut, expireTimestamp, address(this), referrals[msg.sender]);

        uint256 memeBalance = IERC20(meme).balanceOf(address(this));
        IERC20(meme).transfer(msg.sender, memeBalance);
        uint256 baseBalance = IERC20(base).balanceOf(address(this));
        IBase(base).withdraw(baseBalance);
        (bool success, ) = msg.sender.call{value: baseBalance}("");
        require(success, "Failed to send ETH");

        emit MemeRouter__Buy(meme, msg.sender, referrals[msg.sender], msg.value, memeBalance, block.timestamp);
    }

    function sell(
        address meme,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 expireTimestamp
    ) external {
        IERC20(meme).transferFrom(msg.sender, address(this), amountIn);
        IERC20(meme).approve(meme, amountIn);
        IMeme(meme).sell(amountIn, minAmountOut, expireTimestamp, address(this));

        uint256 baseBalance = IERC20(base).balanceOf(address(this));
        IBase(base).withdraw(baseBalance);
        (bool success, ) = msg.sender.call{value: baseBalance}("");
        require(success, "Failed to send ETH");
        IERC20(meme).transfer(msg.sender, IERC20(meme).balanceOf(address(this)));

        emit MemeRouter__Sell(meme, msg.sender, baseBalance, amountIn, block.timestamp);
    }

    function claimFees(address[] calldata memes) external {
        for (uint256 i = 0; i < memes.length; i++) {
            IMeme(memes[i]).claimFees(msg.sender);
            emit MemeRouter__ClaimFees(memes[i], msg.sender);
        }
    }

    function createMeme(
        string memory name,
        string memory symbol,
        string memory uri
    ) external payable returns (address) {
        IBase(base).deposit{value: msg.value}();
        IERC20(base).approve(factory, msg.value);
        address meme = IMemeFactory(factory).createMeme(name, symbol, uri, msg.sender, msg.value);
        IERC20(meme).transfer(msg.sender, IERC20(meme).balanceOf(address(this)));
        IERC20(base).transfer(msg.sender, IERC20(base).balanceOf(address(this)));
        emit MemeRouter__MemeCreated(meme, msg.sender);
        return meme;
    }

    function updateStatus(address meme, string memory status) external {
        IERC20(meme).transferFrom(msg.sender, address(this), STATUS_UPDATE_FEE);
        IMeme(meme).updateStatus(msg.sender, status);
        emit MemeRouter__StatusUpdated(meme, msg.sender, status);
    }

    function contribute(address meme) external payable {
        address preMeme = IMeme(meme).preMeme();
        IBase(base).deposit{value: msg.value}();
        IERC20(base).approve(preMeme, msg.value);
        IPreMeme(preMeme).contribute(msg.sender, msg.value);
        emit MemeRouter__Contributed(meme, msg.sender, msg.value);
    }

    function redeem(address meme) external {
        address preMeme = IMeme(meme).preMeme();
        if (block.timestamp > IPreMeme(preMeme).endTimestamp() && !IPreMeme(preMeme).ended()) {
            IPreMeme(preMeme).openMarket();
            emit MemeRouter__MarketOpened(meme, IPreMeme(preMeme).totalBaseContributed(), IPreMeme(preMeme).totalMemeBalance());
        }
        IPreMeme(preMeme).redeem(msg.sender);
        uint256 memeBalance = IERC20(meme).balanceOf(address(this));
        IERC20(meme).transfer(msg.sender, memeBalance);
        emit MemeRouter__Redeemed(meme, msg.sender, memeBalance);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}