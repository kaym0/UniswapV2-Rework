// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../token/ERC20/ERC20.sol";
import "../token/ERC20/IERC20.sol";
import "../utils/FixedPointMath.sol";

contract RewardVault is ERC20 {
    using FixedPointMath for uint256;

    IERC20 immutable assetToken;
    IERC20 immutable rewardToken;

    uint256 public rewardRate;
    uint256 constant REWARD_LENGTH = 30 days;
    uint256 immutable rewardStart;
    uint256 immutable rewardEnd;

    event Deposit(address indexed owner, address indexed receiver, uint256 assets);
    event Withdraw(address indexed owner, address indexed receiver, uint256 assets, uint256 shares);
    event Claim(address indexed owner, address indexed receiver, uint256 amount);

    mapping (address => uint256) public lastRewardTime;

    constructor(address assetToken_, address rewardToken_) {
        /// ERC20 setters
        name = "ManaSwapRewardVault";
        symbol = "rMana";
        decimals = 18;

        assetToken = IERC20(assetToken_);
        rewardToken = IERC20(rewardToken_);
        rewardStart = block.timestamp;
        rewardEnd = block.timestamp + REWARD_LENGTH;
    }

    /**
     *  @dev Claims any reward availble to the owner
     *  @notice This is callable on behalf of the owner. If the owners last claimed time is 0 (default) it sets it to the current time.
     *  @param owner - The address to claim the reward from
     *  @param receiver - The address to disperse the reward to
     */
    modifier getReward(address owner, address receiver) {
        if (lastRewardTime[owner] != 0) {
            claimReward(owner, receiver);
        } else {
            lastRewardTime[owner] = block.timestamp;
        }

        _;
    }

    /**
     *  @dev Gets the total supply of assets in this contract
     *  @return assetAmount - The total assets locked in this contract
     */
    function totalAssets() public view returns (uint256) {
        return IERC20(assetToken).balanceOf(address(this));
    }

    /**
     *  @dev View shares by account
     *  @param owner - The account to query
     *  @return shares - The owners total shares
     */
    function viewUserShares(address owner) public view returns (uint256) {
        return convertToShares(balanceOf(owner));
    }


    function convertToShares(uint256 assets) public view virtual  returns (uint256) {
        uint256 value = _totalSupply;
        return value == 0
            ? assets 
            : assets.mulDivDown(value, totalAssets())
            ; 
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        uint256 value = _totalSupply;
        return value == 0
            ? shares 
            : shares.mulDivDown(value, totalAssets())
            ; 
    }

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function previewReward(address owner) public view virtual returns (uint256) {
        uint256 shares = convertToShares(balanceOf(owner));
        return _getRewardAmount(shares, owner);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 value = _totalSupply;
        return value == 0
            ? shares
            : shares.mulDivUp(totalAssets(), value)
            ;
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        uint256 value = _totalSupply;
        return value == 0
            ? assets 
            : assets.mulDivUp(value, totalAssets())
            ;
    }

    /**
     *  @dev Notifies the contract that tokens have been added.
     *  @notice This uses internal numbers to calculate the reward rate to help mitigate human error.
     *  @return rewardRate - The per second rate at which rewards are dispersed.
     */
    function addReward() public returns (uint256) {
        uint256 rewardAmount = rewardToken.balanceOf(address(this));
        return rewardRate = ((rewardAmount * 10000) / REWARD_LENGTH) / 10000;
    }

    /**
     *  @dev transfer override. This prevents transferring after claim to redeem additional rewards.
     *  @param to - The address to send tokens to
     *  @param amount - The amount of tokens to send.
     *  @return success - True if successful. This will always return true if the function does not revert.
     */
    function transfer(address to, uint256 amount) public override 
        getReward(_msgSender(), to) 
        getReward(to, _msgSender()) 
        returns (bool) {
            return super.transfer(to, amount);
    }

    /**
     *  @dev transferFrom override. This prevents transferring after claiming to redeem additional rewards.
     *  @param from - The address to transfer from
     *  @param to - The address to transfer to
     *  @param amount - The amount of tokens to transfer
     *  @return success - Returns true if this function does not revert.
     */
    function transferFrom(address from, address to, uint256 amount) public override 
        getReward(_msgSender(), to) 
        getReward(to, _msgSender()) 
        returns (bool) {
            return super.transferFrom(from, to, amount);
    }

    /**
     *  @dev Deposits assets
     *  @notice Assets can be deposited on the behalf of an owner
     *  @param assets - The amount of assetToken to deposit
     *  @param owner - The owner of the tokens to deposit
     *  @param receiver - The receiver of the minted tokens
     *  @return shares - The amount of shares received
     */
    function deposit(uint256 assets, address owner, address receiver) public getReward(owner, receiver) returns (uint256 shares) {
        require((shares = previewDeposit(assets)) != 0, "No Shares");

        assetToken.transferFrom(owner, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(owner, receiver, shares);
    }

    function depositAll(address owner, address receiver) public getReward(owner, receiver) returns (uint256) {
        return deposit(assetToken.balanceOf(owner), owner, receiver);
    }

    /**
     *  @dev Withdraws assets
     *  @notice Assets can be withdrawn on the behalf of an owner
     *  @param assets - The amount of assetToken to deposit
     *  @param owner - The owner of the tokens to deposit
     *  @param receiver - The receiver of the minted tokens
     *  @return shares - The amount of shares received
     */
    function withdraw(uint256 assets, address owner, address receiver) public getReward(owner, receiver) returns (uint256 shares) {
        shares = previewWithdraw(assets);

        if (_msgSender() != owner) {
            uint256 allowed = _allowances[owner][_msgSender()];

            if (allowed != type(uint256).max) _allowances[owner][_msgSender()] = allowed - shares;
        }

        _burn(owner, shares);

        emit Withdraw(owner, receiver, assets, shares);

        assetToken.transfer(receiver, assets);
    }

    function withdrawAll(address owner, address receiver) public getReward(owner, receiver) returns (uint256) {
        return withdraw(balanceOf(owner), owner, receiver);
    }

    /**
     *  @dev Claims any reward available to the owner
     *  @notice This can be called on behalf of the owner.
     *  @param owner - The wallet of the owner of the deposited assets
     *  @param receiver - the wallet of the receiver of the claimed rewardToken
     *  @return rewardAmount - The amount claimed
     */
    function claimReward(address owner, address receiver) public returns (uint256 rewardAmount) {
        uint256 shares = convertToShares(balanceOf(owner));

        if (shares == 0) return 0;

        rewardAmount = _getRewardAmount(shares, owner);

        rewardToken.transfer(receiver, rewardAmount);
        lastRewardTime[owner] = block.timestamp;

        emit Claim(owner, receiver, rewardAmount);
    }

    /**
     *  @dev Calculates the reward amount received by an owner
     *  @param shares - The number of shares owned by an owner
     *  @param owner - The owner of the shares
     *  @return rewardAmount - The total reward for the receiver
     */
    function _getRewardAmount(uint256 shares, address owner) internal view returns (uint256 rewardAmount) {
        if (block.timestamp > rewardEnd) {
            //return rewardRate.mulDivDown(shares, totalAssets());
            return (rewardEnd - lastRewardTime[owner]) * rewardRate.mulDivDown(shares, totalAssets());
        }

        return (block.timestamp - lastRewardTime[owner]) * rewardRate.mulDivDown(balanceOf(owner), totalAssets());
    }
}